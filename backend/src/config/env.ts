import 'dotenv/config';
import { z } from 'zod';

const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(4000),
    DATABASE_URL: z.string().min(1),
    DIRECT_URL: z.string().min(1),
    CORS_ORIGINS: z.string().default('http://localhost:8080'),
    JWT_SECRET: z.string().min(16),
    JWT_EXPIRES_IN: z.string().default('7d'),
    DEMO_OTP_ENABLED: z
      .enum(['true', 'false'])
      .default('false')
      .transform((value) => value === 'true'),
    DEMO_OTP_CODE: z.string().regex(/^\d{4,6}$/).default('9001'),
    SUPER_ADMIN_PHONE: z.string().regex(/^\+?\d{8,15}$/).optional(),
    SUPER_ADMIN_EMAIL: z.string().email().optional(),
    SUPER_ADMIN_PASSWORD: z.string().min(12).optional(),
  })
  .superRefine((env, ctx) => {
    if (env.NODE_ENV === 'production' && env.DEMO_OTP_ENABLED) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['DEMO_OTP_ENABLED'],
        message: 'Demo OTP must be disabled when NODE_ENV is production',
      });
    }
  });

export const env = envSchema.parse(process.env);

export const corsOrigins = env.CORS_ORIGINS.split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
