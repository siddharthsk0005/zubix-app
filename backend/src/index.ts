import { app } from './app';
import { env } from './config/env';
import { prisma } from './lib/prisma';
import { seedSuperAdmin } from './lib/seed';

let server: ReturnType<typeof app.listen> | undefined;

seedSuperAdmin()
  .catch((error) => console.error('Super admin seed failed', error))
  .finally(() => {
    server = app.listen(env.PORT, () => {
      console.log(`Zubix API listening on port ${env.PORT} (${env.NODE_ENV})`);
    });
  });

async function shutdown(signal: string) {
  console.log(`${signal} received, shutting down`);
  server?.close();

  await prisma.$disconnect();
  process.exit(0);
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
