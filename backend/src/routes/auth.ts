import { Router } from 'express';
import { z } from 'zod';
import { env } from '../config/env';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';
import { requireAuth, signToken } from '../middleware/auth';

export const authRouter = Router();

// Accepts an optional leading "+" followed by 8 to 15 digits.
const phoneSchema = z
  .string()
  .trim()
  .regex(/^\+?\d{8,15}$/, 'Enter a valid phone number');

const otpRequestSchema = z.object({ phone: phoneSchema });

const otpVerifySchema = z.object({
  phone: phoneSchema,
  code: z.string().trim().min(4).max(6),
});

authRouter.post('/otp/request', (req, res, next) => {
  try {
    otpRequestSchema.parse(req.body);
    if (!env.DEMO_OTP_ENABLED) {
      // SMS delivery is not configured yet. Fail loudly instead of pretending to send.
      throw new AppError(503, 'OTP_PROVIDER_NOT_CONFIGURED', 'Phone verification is not available yet');
    }
    res.json({ sent: true, demo: true });
  } catch (error) {
    next(error);
  }
});

authRouter.post('/otp/verify', async (req, res, next) => {
  try {
    const { phone, code } = otpVerifySchema.parse(req.body);
    if (!env.DEMO_OTP_ENABLED) {
      throw new AppError(503, 'OTP_PROVIDER_NOT_CONFIGURED', 'Phone verification is not available yet');
    }
    if (code !== env.DEMO_OTP_CODE) {
      throw new AppError(401, 'INVALID_OTP', 'The code you entered is incorrect');
    }

    // First sign-in creates a pending account that an admin must approve.
    const user = await prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone },
      select: { id: true, phone: true, role: true, status: true, name: true },
    });

    res.json({ token: signToken(user.id), user });
  } catch (error) {
    next(error);
  }
});

// Social sign-in needs provider credentials (Google and Apple client IDs) before it can be verified.
authRouter.post(['/social/google', '/social/apple'], (_req, _res, next) => {
  next(new AppError(501, 'NOT_CONFIGURED', 'Social sign-in is not configured yet'));
});

authRouter.get('/me', requireAuth, async (req, res, next) => {
  try {
    const user = await prisma.user.findUniqueOrThrow({
      where: { id: req.auth!.id },
      select: { id: true, phone: true, email: true, name: true, role: true, status: true },
    });
    res.json({ user });
  } catch (error) {
    next(error);
  }
});
