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

## Status

Rewrite in progress. The previous prototype is archived in the `zubix` repository.

## Local development

```bash
# Backend
cd backend
cp .env.example .env   # fill in DATABASE_URL and DIRECT_URL
npm install
npm run dev

# Client
flutter pub get
flutter run -d chrome --web-port=8080
```

## Quality gates

- `flutter analyze` must report 0 issues.
- `flutter test` must pass.
- `npx tsc --noEmit` must pass in `backend/`.
