import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';
import { distanceMeters } from '../lib/geo';
import { displayCouponStatus, syncSessionStatuses } from '../lib/sessions';
import { requireApproved, requireAuth, requireRole } from '../middleware/auth';

export const sessionsRouter = Router();
export const couponsRouter = Router();

const idSchema = z.string().uuid();
const shopperGuard = [requireAuth, requireRole('USER'), requireApproved] as const;
sessionsRouter.use(...shopperGuard);
couponsRouter.use(...shopperGuard);

const sessionInclude = {
  brand: { select: { id: true, name: true, kind: true } },
  category: { select: { id: true, name: true } },
} as const;

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

/** Adds the shopper's own coupon, claim countdown, and remaining stock to each session. */
async function withShopperState<T extends { id: string; couponExpiresAt: Date }>(
  sessions: T[],
  userId: string,
  now: Date,
) {
  const ids = sessions.map((session) => session.id);
  const [remaining, mine, tickets] = await Promise.all([
    prisma.coupon.groupBy({
      by: ['sessionId'],
      where: { sessionId: { in: ids }, status: 'AVAILABLE' },
      _count: { _all: true },
    }),
    prisma.coupon.findMany({
      where: { sessionId: { in: ids }, userId },
      select: { id: true, sessionId: true, code: true, status: true, expiresAt: true },
    }),
    prisma.claimTicket.findMany({
      where: { sessionId: { in: ids }, userId },
      select: { sessionId: true, readyAt: true },
    }),
  ]);

  return sessions.map((session) => {
    const coupon = mine.find((item) => item.sessionId === session.id);
    const ticket = tickets.find((item) => item.sessionId === session.id);
    return {
      ...session,
      couponsLeft: remaining.find((item) => item.sessionId === session.id)?._count._all ?? 0,
      myCoupon: coupon
        ? {
            id: coupon.id,
            code: coupon.code,
            status: displayCouponStatus(coupon.status, coupon.expiresAt, now),
            expiresAt: coupon.expiresAt,
          }
        : null,
      claimReadyAt: ticket?.readyAt ?? null,
    };
  });
}

const listQuerySchema = z
  .object({
    kind: z.enum(['ONLINE', 'LOCAL_STORE']).optional(),
    latitude: z.coerce.number().min(-90).max(90).optional(),
    longitude: z.coerce.number().min(-180).max(180).optional(),
  })
  .refine((value) => value.kind !== 'LOCAL_STORE' || (value.latitude !== undefined && value.longitude !== undefined), {
    message: 'Location is required for nearby sessions',
    path: ['latitude'],
  });

/** Live sessions and approved sessions that have not started yet.
 * `kind=ONLINE` lists brand sessions, `kind=LOCAL_STORE` lists nearby store sessions within each store's radius.
 */
sessionsRouter.get('/', async (req, res, next) => {
  try {
    const query = listQuerySchema.parse(req.query);
    const now = new Date();
    await syncSessionStatuses(now);
    const sessions = await prisma.session.findMany({
      where: {
        AND: [
          { OR: [{ status: 'LIVE' }, { status: 'APPROVED', startsAt: { gt: now } }] },
          ...(query.kind ? [{ brand: { kind: query.kind } }] : []),
        ],
      },
      orderBy: { startsAt: 'asc' },
      include: {
        ...sessionInclude,
        brand: { select: { id: true, name: true, kind: true, latitude: true, longitude: true, radiusMeters: true } },
      },
    });

    let visible = sessions;
    if (query.kind === 'LOCAL_STORE') {
      visible = sessions.filter(
        (session) =>
          session.brand.latitude !== null &&
          session.brand.longitude !== null &&
          session.brand.radiusMeters !== null &&
          distanceMeters(query.latitude!, query.longitude!, session.brand.latitude, session.brand.longitude) <=
            session.brand.radiusMeters,
      );
    }

    const page = visible.slice(0, 100).map(({ brand, ...session }) => ({
      ...session,
      brand: { id: brand.id, name: brand.name, kind: brand.kind },
    }));
    res.json({ serverTime: now, sessions: await withShopperState(page, req.auth!.id, now) });
  } catch (error) {
    next(error);
  }
});


sessionsRouter.get('/:id', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const now = new Date();
    await syncSessionStatuses(now);
    const session = await prisma.session.findUnique({ where: { id }, include: sessionInclude });
    if (!session || !['APPROVED', 'LIVE', 'ENDED'].includes(session.status)) {
      throw new AppError(404, 'NOT_FOUND', 'Session not found');
    }
    const [decorated] = await withShopperState([session], req.auth!.id, now);
    res.json({ serverTime: now, session: decorated });
  } catch (error) {
    next(error);
  }
});

/** Starts the countdown. Calling it again returns the same ready time.
 * Nearby (local store) sessions also need the shopper's location inside the store's radius.
 */
sessionsRouter.post('/:id/claim/start', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const userId = req.auth!.id;
    const now = new Date();
    await syncSessionStatuses(now);

    const session = await prisma.session.findUnique({
      where: { id },
      select: {
        status: true,
        waitingSeconds: true,
        couponExpiresAt: true,
      },
    });
    if (!session) throw new AppError(404, 'NOT_FOUND', 'Session not found');
    assertClaimable(session.status, session.couponExpiresAt, now);

    const claimed = await prisma.coupon.findFirst({ where: { sessionId: id, userId }, select: { id: true } });
    if (claimed) {
      throw new AppError(409, 'ALREADY_CLAIMED', 'You have already claimed a coupon for this session');
    }

    const existing = await prisma.claimTicket.findUnique({
      where: { sessionId_userId: { sessionId: id, userId } },
    });
    const ticket =
      existing ??
      (await createTicket(id, userId, new Date(now.getTime() + session.waitingSeconds * 1000)));

    res.json({ readyAt: ticket.readyAt, serverTime: now, waitingSeconds: session.waitingSeconds });
  } catch (error) {
    next(error);
  }
});

sessionsRouter.post('/:id/claim', async (req, res, next) => {
  try {
    const id = idSchema.parse(req.params.id);
    const userId = req.auth!.id;
    const now = new Date();
    await syncSessionStatuses(now);

    const session = await prisma.session.findUnique({
      where: { id },
      select: { status: true, couponExpiresAt: true },
    });
    if (!session) throw new AppError(404, 'NOT_FOUND', 'Session not found');
    assertClaimable(session.status, session.couponExpiresAt, now);

    const ticket = await prisma.claimTicket.findUnique({
      where: { sessionId_userId: { sessionId: id, userId } },
    });
    if (!ticket) {
      throw new AppError(409, 'CLAIM_NOT_STARTED', 'Start the countdown before claiming');
    }
    if (now < ticket.readyAt) {
      const secondsLeft = Math.ceil((ticket.readyAt.getTime() - now.getTime()) / 1000);
      throw new AppError(409, 'TOO_EARLY', `Wait ${secondsLeft} more seconds before claiming`);
    }

    const coupon = await claimCoupon(id, userId, now);
    res.json({
      coupon: {
        id: coupon.id,
        code: coupon.code,
        status: displayCouponStatus(coupon.status, coupon.expiresAt, now),
        expiresAt: coupon.expiresAt,
      },
    });
  } catch (error) {
    next(error);
  }
});

couponsRouter.get('/me', async (req, res, next) => {
  try {
    const now = new Date();
    await syncSessionStatuses(now);
    const coupons = await prisma.coupon.findMany({
      where: { userId: req.auth!.id },
      orderBy: { claimedAt: 'desc' },
      take: 100,
      include: {
        session: {
          select: {
            id: true,
            title: true,
            discountPercent: true,
            endsAt: true,
            brand: { select: { name: true } },
          },
        },
      },
    });
    res.json({
      serverTime: now,
      coupons: coupons.map((coupon) => ({
        id: coupon.id,
        code: coupon.code,
        status: displayCouponStatus(coupon.status, coupon.expiresAt, now),
        claimedAt: coupon.claimedAt,
        expiresAt: coupon.expiresAt,
        session: coupon.session,
      })),
    });
  } catch (error) {
    next(error);
  }
});

function assertClaimable(status: string, couponExpiresAt: Date, now: Date): void {
  if (status !== 'LIVE') {
    throw new AppError(409, 'SESSION_NOT_LIVE', 'This session is not live right now');
  }
  if (now.getTime() >= couponExpiresAt.getTime()) {
    throw new AppError(409, 'COUPONS_EXPIRED', 'Coupons for this session have expired');
  }
}

async function createTicket(sessionId: string, userId: string, readyAt: Date) {
  try {
    return await prisma.claimTicket.create({ data: { sessionId, userId, readyAt } });
  } catch (error) {
    // A parallel start request won the race. Its ticket is the one to use.
    if (!isUniqueViolation(error)) throw error;
    return prisma.claimTicket.findUniqueOrThrow({ where: { sessionId_userId: { sessionId, userId } } });
  }
}

/**
 * Assigns one available coupon. The unique (sessionId, userId) constraint means a
 * shopper can never end up with two coupons, even when requests race.
 */
async function claimCoupon(sessionId: string, userId: string, now: Date) {
  for (let attempt = 0; attempt < 10; attempt++) {
    const existing = await prisma.coupon.findFirst({ where: { sessionId, userId } });
    if (existing) return existing;

    const next = await prisma.coupon.findFirst({
      where: { sessionId, status: 'AVAILABLE' },
      select: { id: true },
    });
    if (!next) {
      throw new AppError(409, 'SOLD_OUT', 'All coupons for this session have been claimed');
    }

    try {
      const result = await prisma.coupon.updateMany({
        where: { id: next.id, status: 'AVAILABLE' },
        data: { status: 'CLAIMED', userId, claimedAt: now },
      });
      if (result.count === 1) {
        return await prisma.coupon.findUniqueOrThrow({ where: { id: next.id } });
      }
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // Another request for this shopper already claimed. Loop to return it.
    }
  }
  throw new AppError(503, 'BUSY', 'Too many people are claiming right now. Please try again');
}
