import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import type { AccountStatus, Role } from '@prisma/client';
import { env } from '../config/env';
import { prisma } from '../lib/prisma';
import { AppError } from '../lib/errors';

export interface AuthUser {
  id: string;
  role: Role;
  status: AccountStatus;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: AuthUser;
    }
  }
}

export function signToken(userId: string): string {
  return jwt.sign({}, env.JWT_SECRET, {
    subject: userId,
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  });
}

/**
 * Verifies the bearer token and loads the current account from the database,
 * so a rejected or suspended account loses access immediately.
 */
export async function requireAuth(req: Request, _res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) {
      throw new AppError(401, 'UNAUTHENTICATED', 'Sign in required');
    }

    let userId: string;
    try {
      const payload = jwt.verify(token, env.JWT_SECRET);
      if (typeof payload !== 'object' || typeof payload.sub !== 'string') {
        throw new Error('Invalid token payload');
      }
      userId = payload.sub;
    } catch {
      throw new AppError(401, 'INVALID_TOKEN', 'Session expired. Please sign in again');
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, role: true, status: true },
    });
    if (!user) {
      throw new AppError(401, 'INVALID_TOKEN', 'Session expired. Please sign in again');
    }

    req.auth = user;
    next();
  } catch (error) {
    next(error);
  }
}

export function requireRole(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.auth) {
      return next(new AppError(401, 'UNAUTHENTICATED', 'Sign in required'));
    }
    if (!roles.includes(req.auth.role)) {
      return next(new AppError(403, 'FORBIDDEN', 'You do not have access to this resource'));
    }
    next();
  };
}

/** Blocks accounts that are still pending review or were rejected. */
export function requireApproved(req: Request, _res: Response, next: NextFunction) {
  if (!req.auth) {
    return next(new AppError(401, 'UNAUTHENTICATED', 'Sign in required'));
  }
  if (req.auth.status !== 'APPROVED') {
    return next(new AppError(403, 'ACCOUNT_NOT_APPROVED', 'Your account is awaiting approval'));
  }
  next();
}
