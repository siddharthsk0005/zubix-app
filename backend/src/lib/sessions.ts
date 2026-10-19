import { randomInt } from 'node:crypto';
import { prisma } from './prisma';

// Excludes look-alike characters (0/O, 1/I) so codes are easy to read aloud.
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function generateCouponCodes(count: number): string[] {
  const codes = new Set<string>();
  while (codes.size < count) {
    let code = 'ZB-';
    for (let i = 0; i < 4; i++) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
    code += '-';
    for (let i = 0; i < 4; i++) code += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
    codes.add(code);
  }
  return [...codes];
}

/**
 * Moves sessions along their lifecycle based on the clock:
 * APPROVED -> LIVE when the start time arrives, and -> ENDED when the end time passes.
 * Runs on reads and writes instead of a scheduler, so statuses are always current.
 */
export async function syncSessionStatuses(now: Date = new Date()): Promise<void> {
  await prisma.$transaction([
    prisma.session.updateMany({
      where: { status: 'APPROVED', startsAt: { lte: now }, endsAt: { gt: now } },
      data: { status: 'LIVE' },
    }),
    prisma.session.updateMany({
      where: { status: { in: ['APPROVED', 'LIVE'] }, endsAt: { lte: now } },
      data: { status: 'ENDED' },
    }),
  ]);
}

/** A claimed coupon past its expiry shows as EXPIRED, even before any job updates it. */
export function displayCouponStatus(status: string, expiresAt: Date, now: Date = new Date()): string {
  if (status === 'CLAIMED' && expiresAt.getTime() < now.getTime()) return 'EXPIRED';
  return status;
}
