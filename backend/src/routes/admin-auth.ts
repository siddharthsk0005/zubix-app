import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';
import { signToken } from '../middleware/auth';

export const adminAuthRouter = Router();

const MAX_FAILED_ATTEMPTS = 5;
const LOCK_WINDOW_MS = 15 * 60 * 1000;

// In-memory lockout per email. Resets on restart; move to a shared store if the API scales out.
const failures = new Map<string, { count: number; firstAt: number }>();

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1).max(200),
});

// A dummy hash lets unknown emails take the same time as real ones.
const DUMMY_HASH = bcrypt.hashSync('dummy-password-for-timing', 12);

function isLocked(key: string): boolean {
  const entry = failures.get(key);
  if (!entry) return false;
  if (Date.now() - entry.firstAt > LOCK_WINDOW_MS) {
    failures.delete(key);
    return false;
  }
  return entry.count >= MAX_FAILED_ATTEMPTS;
}

function recordFailure(key: string): void {
  const entry = failures.get(key);
  if (!entry || Date.now() - entry.firstAt > LOCK_WINDOW_MS) {
    failures.set(key, { count: 1, firstAt: Date.now() });
  } else {
    entry.count += 1;
  }
}

adminAuthRouter.post('/login', async (req, res, next) => {
  try {
    const { email, password } = loginSchema.parse(req.body);
    const key = email;
    if (isLocked(key)) {
      throw new AppError(429, 'TOO_MANY_ATTEMPTS', 'Too many failed attempts. Try again in 15 minutes');
    }

    const user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, name: true, role: true, status: true, passwordHash: true },
    });
    const valid = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);

    if (!user || !user.passwordHash || !valid || user.role !== 'ADMIN' || user.status !== 'APPROVED') {
      recordFailure(key);
      throw new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect');
    }

    failures.delete(key);
    res.json({
      token: signToken(user.id),
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
    });
  } catch (error) {
    next(error);
  }
});
