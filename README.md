# Zubix

Zubix is a luxury commerce and interactive discovery platform. It connects D2C online brands, local physical stores, and shoppers through timed Generative Drop Sessions and in-store vouchers.

## Surfaces

- **Shopper app** (`/`): discover brands, explore nearby stores, join drop sessions, claim and display vouchers.
- **Brand partner portal** (`/brands`): register, log in, request drop sessions, and manage the brand profile.
- **Admin panel** (`/admin`): approve brand registrations and session requests, and monitor live sessions.

## Stack

- Flutter (iOS, Android, and web) for the client apps
- Node.js, Express, TypeScript, and Prisma for the backend
- PostgreSQL (Supabase) for data

## Repository layout

- `apps/mobile/`: Flutter app for shoppers (Android and iOS)
- `apps/web/`: Flutter Web app for the brand dashboard and admin panel
- `backend/`: Express API with Prisma schema and migrations
- `.github/workflows/ci.yml`: CI for backend and both Flutter apps

## Status

Phase 1 (foundations) in progress: project scaffolding, Prisma schema, OTP auth (demo code), and role middleware. The previous prototype is archived in the `zubix` repository.

## Local development

```bash
# Backend
cd backend
cp .env.example .env   # fill in DATABASE_URL, DIRECT_URL, and JWT_SECRET
npm install
npm run prisma:generate
npm run dev            # http://localhost:4000/health

# Mobile app
cd apps/mobile
flutter pub get
flutter run

# Web app (brand dashboard and admin panel)
cd apps/web
flutter pub get
flutter run -d chrome --web-port=8080
```

Demo OTP: set `DEMO_OTP_ENABLED=true` and use code `9001`. This is refused when `NODE_ENV=production`.

## Quality gates

- `flutter analyze` must report 0 issues.
- `flutter test` must pass.
- `npx tsc --noEmit` must pass in `backend/`.
