import bcrypt from 'bcryptjs';
import { env } from '../config/env';
import { prisma } from './prisma';

/**
 * Creates or updates the single super admin from env vars on startup.
 * Skipped when the variables are not set. The password is never logged.
 */
export async function seedSuperAdmin(): Promise<void> {
  const { SUPER_ADMIN_EMAIL, SUPER_ADMIN_PASSWORD, SUPER_ADMIN_PHONE } = env;
  if (!SUPER_ADMIN_EMAIL || !SUPER_ADMIN_PASSWORD || !SUPER_ADMIN_PHONE) {
    console.log('Super admin not seeded: set SUPER_ADMIN_EMAIL, SUPER_ADMIN_PHONE and SUPER_ADMIN_PASSWORD');
    return;
  }

  const email = SUPER_ADMIN_EMAIL.toLowerCase();
  const passwordHash = await bcrypt.hash(SUPER_ADMIN_PASSWORD, 12);
  await prisma.user.upsert({
    where: { email },
    update: { passwordHash, role: 'ADMIN', status: 'APPROVED', phone: SUPER_ADMIN_PHONE },
    create: {
      email,
      phone: SUPER_ADMIN_PHONE,
      passwordHash,
      role: 'ADMIN',
      status: 'APPROVED',
      name: 'Super Admin',
    },
  });
  console.log(`Super admin ready: ${email}`);
}
