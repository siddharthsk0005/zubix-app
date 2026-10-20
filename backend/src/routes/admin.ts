import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';
import { requireAuth, requireRole } from '../middleware/auth';
import { generateCouponCodes, syncSessionStatuses } from '../lib/sessions';

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRole('ADMIN'));

const reviewSchema = z
  .object({
    decision: z.enum(['APPROVE', 'REJECT']),
    note: z.string().trim().max(500).optional(),
    // Per-session overrides, applied only when approving.
    waitingSeconds: z.number().int().min(10).max(120).optional(),
    couponExpiresAt: z.coerce.date().optional(),
  })
  .refine((value) => value.decision !== 'REJECT' || (value.note && value.note.length > 0), {
    message: 'A note is required when rejecting',
    path: ['note'],
  })
  .refine(
    (value) =>
      value.decision === 'APPROVE' ||
      (value.waitingSeconds === undefined && value.couponExpiresAt === undefined),
    { message: 'Timing overrides can only be set when approving', path: ['decision'] },
  );

const statusFilter = z.enum(['PENDING', 'APPROVED', 'REJECTED']).optional();
const idSchema = z.string().uuid();

adminRouter.get('/users', async (req, res, next) => {
  try {
    const status = statusFilter.parse(req.query.status);
    const users = await prisma.user.findMany({
      where: { role: 'USER', ...(status ? { status } : {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
      select: { id: true, phone: true, email: true, name: true, status: true, reviewNote: true, reviewedAt: true, createdAt: true },
    });
    res.json({ users });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/users/:id/review', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const { decision, note } = reviewSchema.parse(req.body);
    const status = decision === 'APPROVE' ? 'APPROVED' : 'REJECTED';

    const target = await prisma.user.findUnique({ where: { id }, select: { role: true } });
    if (!target || target.role !== 'USER') {
      throw new AppError(404, 'NOT_FOUND', 'Account not found');
    }

    const user = await prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id },
        data: { status, reviewNote: note ?? null, reviewedAt: new Date() },
        select: { id: true, phone: true, name: true, status: true, reviewNote: true, reviewedAt: true },
      });
      await tx.auditLog.create({
        data: {
          actorId: req.auth!.id,
          action: `USER_${decision}`,
          entityType: 'User',
          entityId: id,
          metadata: { note: note ?? null },
        },
      });
      return updated;
    });
    res.json({ user });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/brands', async (req, res, next) => {
  try {
    const status = statusFilter.parse(req.query.status);
    const brands = await prisma.brand.findMany({
      where: status ? { status } : {},
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { category: { select: { id: true, name: true } } },
    });
    res.json({ brands });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/brands/:id/review', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const { decision, note } = reviewSchema.parse(req.body);
    const status = decision === 'APPROVE' ? 'APPROVED' : 'REJECTED';

    const brand = await prisma.$transaction(async (tx) => {
      const existing = await tx.brand.findUnique({ where: { id }, select: { id: true } });
      if (!existing) {
        throw new AppError(404, 'NOT_FOUND', 'Brand not found');
      }
      const updated = await tx.brand.update({
        where: { id },
        data: { status, reviewNote: note ?? null, reviewedAt: new Date() },
      });
      // The owner account mirrors the brand decision so brand sessions pass the approval check.
      await tx.user.update({
        where: { id: updated.ownerId },
        data: { status, reviewNote: note ?? null, reviewedAt: new Date() },
      });
      await tx.auditLog.create({
        data: {
          actorId: req.auth!.id,
          action: `BRAND_${decision}`,
          entityType: 'Brand',
          entityId: id,
          metadata: { note: note ?? null },
        },
      });
      return updated;
    });
    res.json({ brand });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/sessions', async (req, res, next) => {
  try {
    const status = z.enum(['REQUESTED', 'APPROVED', 'REJECTED', 'LIVE', 'ENDED', 'CANCELLED']).optional().parse(req.query.status);
    await syncSessionStatuses();
    const sessions = await prisma.session.findMany({
      where: status ? { status } : {},
      orderBy: { startsAt: 'desc' },
      take: 100,
      include: {
        brand: { select: { id: true, name: true } },
        category: { select: { id: true, name: true } },
      },
    });
    res.json({ sessions });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/sessions/:id/review', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const { decision, note, waitingSeconds, couponExpiresAt } = reviewSchema.parse(req.body);
    const status = decision === 'APPROVE' ? 'APPROVED' : 'REJECTED';

    const session = await prisma.$transaction(async (tx) => {
      const existing = await tx.session.findUnique({
        where: { id },
        select: { id: true, status: true, couponCount: true, couponExpiresAt: true },
      });
      if (!existing) {
        throw new AppError(404, 'NOT_FOUND', 'Session not found');
      }
      if (existing.status !== 'REQUESTED') {
        throw new AppError(409, 'INVALID_STATE', 'Only requested sessions can be reviewed');
      }
      const expiresAt = couponExpiresAt ?? existing.couponExpiresAt;
      if (decision === 'APPROVE' && expiresAt.getTime() <= Date.now()) {
        throw new AppError(400, 'VALIDATION_ERROR', 'Coupon expiry must be in the future');
      }
      const updated = await tx.session.update({
        where: { id },
        data: {
          status,
          reviewNote: note ?? null,
          ...(decision === 'APPROVE' && waitingSeconds !== undefined ? { waitingSeconds } : {}),
          ...(decision === 'APPROVE' && couponExpiresAt ? { couponExpiresAt } : {}),
        },
        include: { brand: { select: { id: true, name: true } } },
      });
      if (decision === 'APPROVE') {
        // Coupons exist from approval so shoppers can claim them once the session goes live.
        await tx.coupon.createMany({
          data: generateCouponCodes(existing.couponCount).map((code) => ({
            code,
            sessionId: id,
            expiresAt,
          })),
        });
      }
      await tx.auditLog.create({
        data: {
          actorId: req.auth!.id,
          action: `SESSION_${decision}`,
          entityType: 'Session',
          entityId: id,
          metadata: { note: note ?? null },
        },
      });
      return updated;
    });
    res.json({ session });
  } catch (error) {
    next(error);
  }
});

const categoryBodySchema = z.object({
  name: z.string().trim().min(2).max(60),
  isActive: z.boolean().optional(),
});

function slugify(name: string): string {
  return name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

adminRouter.get('/categories', async (_req, res, next) => {
  try {
    const categories = await prisma.category.findMany({ orderBy: { displayOrder: 'asc' } });
    res.json({ categories });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/categories', async (req, res, next) => {
  try {
    const { name, isActive } = categoryBodySchema.parse(req.body);
    const slug = slugify(name);
    if (!slug) {
      throw new AppError(400, 'VALIDATION_ERROR', 'Category name must contain letters or numbers');
    }
    const last = await prisma.category.findFirst({ orderBy: { displayOrder: 'desc' }, select: { displayOrder: true } });
    const category = await prisma.category.create({
      data: { name, slug, isActive: isActive ?? true, displayOrder: (last?.displayOrder ?? 0) + 1 },
    });
    res.status(201).json({ category });
  } catch (error) {
    if (error instanceof Error && 'code' in error && (error as { code?: string }).code === 'P2002') {
      return next(new AppError(409, 'DUPLICATE', 'A category with this name already exists'));
    }
    next(error);
  }
});

adminRouter.patch('/categories/:id', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const body = z
      .object({
        name: z.string().trim().min(2).max(60).optional(),
        isActive: z.boolean().optional(),
      })
      .parse(req.body);
    const data: { name?: string; slug?: string; isActive?: boolean } = {};
    if (body.name) {
      data.name = body.name;
      data.slug = slugify(body.name);
    }
    if (body.isActive !== undefined) data.isActive = body.isActive;

    const category = await prisma.category.update({ where: { id }, data });
    res.json({ category });
  } catch (error) {
    if (error instanceof Error && 'code' in error && (error as { code?: string }).code === 'P2025') {
      return next(new AppError(404, 'NOT_FOUND', 'Category not found'));
    }
    if (error instanceof Error && 'code' in error && (error as { code?: string }).code === 'P2002') {
      return next(new AppError(409, 'DUPLICATE', 'A category with this name already exists'));
    }
    next(error);
  }
});

// Receives the full ordered list of category IDs and assigns displayOrder 1..n.
adminRouter.put('/categories/order', async (req, res, next) => {
  try {
    const { ids } = z.object({ ids: z.array(idSchema).min(1).max(200) }).parse(req.body);
    await prisma.$transaction(
      ids.map((id, index) => prisma.category.update({ where: { id }, data: { displayOrder: index + 1 } })),
    );
    const categories = await prisma.category.findMany({ orderBy: { displayOrder: 'asc' } });
    res.json({ categories });
  } catch (error) {
    next(error);
  }
});
