import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';
import { clearFailures, isLocked, recordFailure } from '../lib/login-lockout';
import { isValidGstin } from '../lib/gstin';
import { requireAuth, requireRole, signToken } from '../middleware/auth';
import { syncSessionStatuses } from '../lib/sessions';

export const brandsRouter = Router();

const idSchema = z.string().uuid();
const gstinSchema = z
  .string()
  .trim()
  .toUpperCase()
  .refine(isValidGstin, { message: 'Enter a valid 15-character GSTIN' });

const profileFields = z.object({
  name: z.string().trim().min(2).max(80),
  founderName: z.string().trim().min(2).max(80),
  kind: z.enum(['ONLINE', 'LOCAL_STORE']),
  categoryId: idSchema,
  gstin: gstinSchema,
  registeredAddress: z.string().trim().max(300).nullish(),
  websiteUrl: z.string().trim().url().max(200).nullish(),
  latitude: z.number().min(-90).max(90).nullish(),
  longitude: z.number().min(-180).max(180).nullish(),
  radiusMeters: z.number().int().min(50).max(5000).nullish(),
});

const registerSchema = profileFields.extend({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(10).max(200),
});

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1).max(200),
});

const DUMMY_HASH = bcrypt.hashSync('dummy-password-for-timing', 12);

const brandInclude = { category: { select: { id: true, name: true } } } as const;

/** A local store must have a location so shoppers can find it nearby. */
function assertLocationForKind(kind: string, data: { latitude?: number | null; longitude?: number | null; radiusMeters?: number | null }) {
  if (kind === 'LOCAL_STORE' && (data.latitude == null || data.longitude == null || data.radiusMeters == null)) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Local stores need latitude, longitude and radius');
  }
}

async function assertActiveCategory(categoryId: string) {
  const category = await prisma.category.findFirst({ where: { id: categoryId, isActive: true }, select: { id: true } });
  if (!category) {
    throw new AppError(400, 'VALIDATION_ERROR', 'Choose an available category');
  }
}

async function assertGstinAvailable(gstin: string, exceptBrandId?: string) {
  const existing = await prisma.brand.findFirst({
    where: { gstin, ...(exceptBrandId ? { NOT: { id: exceptBrandId } } : {}) },
    select: { id: true },
  });
  if (existing) {
    throw new AppError(409, 'DUPLICATE', 'This GSTIN is already registered');
  }
}

brandsRouter.post('/auth/register', async (req, res, next) => {
  try {
    const body = registerSchema.parse(req.body);
    assertLocationForKind(body.kind, body);
    await assertActiveCategory(body.categoryId);
    await assertGstinAvailable(body.gstin);

    const passwordHash = await bcrypt.hash(body.password, 12);
    const { user, brand } = await prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email: body.email,
          passwordHash,
          name: body.founderName,
          role: 'BRAND',
          status: 'PENDING',
        },
        select: { id: true, email: true, name: true, role: true, status: true },
      });
      const createdBrand = await tx.brand.create({
        data: {
          ownerId: created.id,
          name: body.name,
          founderName: body.founderName,
          kind: body.kind,
          categoryId: body.categoryId,
          gstin: body.gstin,
          registeredAddress: body.registeredAddress ?? null,
          websiteUrl: body.websiteUrl ?? null,
          latitude: body.latitude ?? null,
          longitude: body.longitude ?? null,
          radiusMeters: body.radiusMeters ?? null,
        },
        include: brandInclude,
      });
      return { user: created, brand: createdBrand };
    });

    res.status(201).json({ token: signToken(user.id), user, brand });
  } catch (error) {
    if (error instanceof Error && 'code' in error && (error as { code?: string }).code === 'P2002') {
      return next(new AppError(409, 'EMAIL_TAKEN', 'An account with this email already exists'));
    }
    next(error);
  }
});

brandsRouter.post('/auth/login', async (req, res, next) => {
  try {
    const { email, password } = loginSchema.parse(req.body);
    const key = `brand:${email}`;
    if (isLocked(key)) {
      throw new AppError(429, 'TOO_MANY_ATTEMPTS', 'Too many failed attempts. Try again in 15 minutes');
    }

    const user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, name: true, role: true, status: true, passwordHash: true },
    });
    const valid = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);

    // Pending and rejected brands can still sign in to see their review status.
    if (!user || !user.passwordHash || !valid || user.role !== 'BRAND') {
      recordFailure(key);
      throw new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect');
    }

    clearFailures(key);
    res.json({
      token: signToken(user.id),
      user: { id: user.id, email: user.email, name: user.name, role: user.role, status: user.status },
    });
  } catch (error) {
    next(error);
  }
});

brandsRouter.use('/me', requireAuth, requireRole('BRAND'));

async function loadOwnBrand(ownerId: string) {
  const brand = await prisma.brand.findUnique({ where: { ownerId }, include: brandInclude });
  if (!brand) {
    throw new AppError(404, 'NOT_FOUND', 'Brand profile not found');
  }
  return brand;
}

brandsRouter.get('/me', async (req, res, next) => {
  try {
    const brand = await loadOwnBrand(req.auth!.id);
    res.json({ brand });
  } catch (error) {
    next(error);
  }
});

brandsRouter.patch('/me', async (req, res, next) => {
  try {
    const body = profileFields.partial().parse(req.body);
    const current = await loadOwnBrand(req.auth!.id);
    const merged = { ...current, ...body };
    assertLocationForKind(merged.kind, merged);
    if (body.categoryId) await assertActiveCategory(body.categoryId);

    const gstinChanged = body.gstin !== undefined && body.gstin !== current.gstin;
    if (gstinChanged) await assertGstinAvailable(body.gstin!, current.id);

    // A changed GSTIN needs fresh admin approval, so the brand goes back to pending.
    const reviewReset = gstinChanged ? { status: 'PENDING' as const, reviewNote: null, reviewedAt: null } : {};

    const brand = await prisma.$transaction(async (tx) => {
      const updated = await tx.brand.update({
        where: { id: current.id },
        data: {
          ...body,
          ...reviewReset,
        },
        include: brandInclude,
      });
      if (gstinChanged) {
        await tx.user.update({
          where: { id: current.ownerId },
          data: { status: 'PENDING', reviewNote: null, reviewedAt: null },
        });
      }
      return updated;
    });
    res.json({ brand });
  } catch (error) {
    if (error instanceof Error && 'code' in error && (error as { code?: string }).code === 'P2002') {
      return next(new AppError(409, 'DUPLICATE', 'This GSTIN is already registered'));
    }
    next(error);
  }
});

const sessionRequestSchema = z
  .object({
    title: z.string().trim().min(3).max(80),
    createdByTag: z.string().trim().min(2).max(30),
    discountPercent: z.number().int().min(1).max(90),
    couponCount: z.number().int().min(1).max(5000),
    startsAt: z.coerce.date(),
    endsAt: z.coerce.date(),
    couponExpiresAt: z.coerce.date(),
    waitingSeconds: z.number().int().min(10).max(120).default(30),
  })
  .superRefine((value, ctx) => {
    if (value.startsAt.getTime() < Date.now() - 60_000) {
      ctx.addIssue({ code: 'custom', path: ['startsAt'], message: 'Start time must be in the future' });
    }
    if (value.endsAt.getTime() <= value.startsAt.getTime()) {
      ctx.addIssue({ code: 'custom', path: ['endsAt'], message: 'End time must be after start time' });
    }
    if (value.couponExpiresAt.getTime() < value.endsAt.getTime()) {
      ctx.addIssue({ code: 'custom', path: ['couponExpiresAt'], message: 'Coupons must stay valid until the session ends' });
    }
  });

brandsRouter.get('/me/sessions', async (req, res, next) => {
  try {
    const brand = await loadOwnBrand(req.auth!.id);
    await syncSessionStatuses();
    const sessions = await prisma.session.findMany({
      where: { brandId: brand.id },
      orderBy: { startsAt: 'desc' },
      take: 100,
      include: { category: { select: { id: true, name: true } } },
    });
    res.json({ sessions });
  } catch (error) {
    next(error);
  }
});

brandsRouter.post('/me/sessions', async (req, res, next) => {
  try {
    const body = sessionRequestSchema.parse(req.body);
    const brand = await loadOwnBrand(req.auth!.id);
    if (brand.status !== 'APPROVED') {
      throw new AppError(403, 'BRAND_NOT_APPROVED', 'Your brand must be approved before requesting sessions');
    }

    const session = await prisma.session.create({
      data: { ...body, brandId: brand.id, categoryId: brand.categoryId },
      include: { category: { select: { id: true, name: true } } },
    });
    res.status(201).json({ session });
  } catch (error) {
    next(error);
  }
});

brandsRouter.post('/me/sessions/:id/cancel', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const brand = await loadOwnBrand(req.auth!.id);
    const session = await prisma.session.findFirst({ where: { id, brandId: brand.id }, select: { id: true, status: true } });
    if (!session) {
      throw new AppError(404, 'NOT_FOUND', 'Session not found');
    }
    if (session.status !== 'REQUESTED' && session.status !== 'APPROVED') {
      throw new AppError(409, 'INVALID_STATE', 'Only requested or approved sessions can be cancelled');
    }
    const updated = await prisma.session.update({
      where: { id },
      data: { status: 'CANCELLED' },
      include: { category: { select: { id: true, name: true } } },
    });
    res.json({ session: updated });
  } catch (error) {
    next(error);
  }
});
