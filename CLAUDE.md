# RJL Lechunan — Ordering & Inventory App

Read this file at the start of every session. The full spec is `docs/PLAN.md`; progress is tracked in `docs/PROGRESS.md`.

## What we are building

An ordering system for **RJL Lechunan**, a lechon business in the Philippines.

- Customers pre-order lechon **by kilo** or **by whole-pig size** (Small/Medium/Large/Jumbo), with automatic **freebies**.
- Payment is **cash on delivery / pickup only**. A **downpayment** is arranged by message between customer and staff; the app only *records* payments.
- Staff process orders; admin manages products, prices, freebies, inventory, daily capacity, users and reports.
- One codebase: **Android app + iPhone app + website** (customer side), and a **staff/admin dashboard** (web, staff screens also on mobile).
- **Free tools only.** Do not add any paid service, paid API, or SMS gateway.

## Stack (do not change without asking)

| Layer | Choice |
| --- | --- |
| App | React Native + **Expo** (latest stable SDK), **TypeScript strict**, **Expo Router** |
| Styling | NativeWind (Tailwind for React Native) |
| Data fetching | `@supabase/supabase-js` + `@tanstack/react-query` |
| Forms / validation | `react-hook-form` + `zod` |
| Cart state | `zustand` persisted with AsyncStorage |
| Dates | `date-fns` + `date-fns-tz`, timezone **Asia/Manila** |
| Backend | **Supabase** Free plan: Postgres, Auth (email + password, staff only), Storage, Realtime |
| Web hosting | **Cloudflare Pages** (static export of Expo web, `web.output = "single"`) |
| App builds | **EAS Build** Free plan (Android APK first, then AAB for Play Store) |
| CI / jobs | GitHub Actions (typecheck + tests, daily keep-awake, weekly DB backup) |
| Tests | `jest-expo` + `@testing-library/react-native`; SQL tests in `supabase/tests/*.sql` run with `psql` |

## Commands

```bash
npm run start            # Expo dev server (press w for web, a for Android)
npm run web              # web only
npm run typecheck        # tsc --noEmit
npm run lint             # eslint
npm test                 # jest
npm run db:types         # npx supabase gen types typescript --local > src/types/database.ts
npm run db:test          # run supabase/tests/*.sql against the local DB
npm run build:web        # npx expo export -p web  -> dist/
npx eas build -p android --profile preview   # installable APK
```

Local database: `npx supabase start` (needs Docker), then `npx supabase db reset` applies `supabase/migrations/*` and `supabase/seed.sql`.

## Non-negotiable rules

1. **Prices, freebies, capacity and stock are computed in Postgres functions**, never trusted from the client. The client calls `quote_cart` to display totals and `place_order` to create orders (see PLAN §6).
2. Customers do **not** have accounts in the MVP. Guest order tracking uses **order number + mobile number** via `get_public_order`.
3. Customers never read or write order tables directly. All customer and staff writes to orders, payments, messages and stock go through `SECURITY DEFINER` functions with role checks. RLS stays enabled on every table.
4. Never ship the Supabase **service role** key in the app or in `EXPO_PUBLIC_*` variables. The app uses only the anon/publishable key.
5. Money: Postgres `numeric(10,2)`; display with `Intl.NumberFormat('en-PH', { style: 'currency', currency: 'PHP' })`. Never use floats for totals on the server.
6. Dates: an order's `scheduled_date` is a Manila calendar date. "Today" means today in Asia/Manila, on the server and the client.
7. Mobile numbers: Philippine format `09XXXXXXXXX` or `+639XXXXXXXXX`; normalise to `09XXXXXXXXX` before saving.
8. UI language: English, short and friendly; currency shown as ₱. Big tap targets (min 44 px), works on small Android phones (360 px wide).
9. Admin screens run on **web only** (`Platform.OS === 'web'`); staff order screens run on web and mobile.
10. Every schema change is a new file in `supabase/migrations/` — never edit an applied migration. Regenerate `src/types/database.ts` after each one.
11. Sample prices and sizes in `seed.sql` are placeholders. Never hard-code prices, sizes, freebies or time slots in the app.

## Conventions

- Routes live in `app/`; reusable code in `src/` (`src/api` for typed Supabase calls, `src/components`, `src/features/<feature>`, `src/lib`).
- One React Query hook per API call (`useMenu`, `useQuote`, `usePlaceOrder`, ...), keys in `src/api/keys.ts`.
- Errors from Postgres functions are raised with a short code in the message (`CAPACITY_FULL`, `INVALID_KG`, ...). Map codes to friendly text in `src/lib/errors.ts`.
- Small, focused commits per task. Run `npm run typecheck && npm test` before saying a task is done.
- After finishing a phase task, tick it in `docs/PROGRESS.md` and note anything the owner must decide.

## When unsure

Ask the owner rather than guessing about business rules (prices, downpayment rules, delivery areas, cancellation). Defaults for open questions are listed in PLAN §2 — use them and flag them in PROGRESS.md.
