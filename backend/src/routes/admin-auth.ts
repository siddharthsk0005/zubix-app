import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';
import { clearFailures, isLocked, recordFailure } from '../lib/login-lockout';
import { signToken } from '../middleware/auth';

export const adminAuthRouter = Router();

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1).max(200),
});

// A dummy hash lets unknown emails take the same time as real ones.
const DUMMY_HASH = bcrypt.hashSync('dummy-password-for-timing', 12);

adminAuthRouter.post('/login', async (req, res, next) => {
  try {
    const { email, password } = loginSchema.parse(req.body);
    const key = `admin:${email}`;
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

    clearFailures(key);
    res.json({
      token: signToken(user.id),
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
    });
  } catch (error) {
    next(error);
  }
});
