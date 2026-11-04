# Progress — RJL Lechunan

Claude Code: tick tasks as you finish them, and add notes for the owner under "Decisions needed".

| Phase | Status | Notes |
| --- | --- | --- |
| 0 — Project setup | In progress | All code done. Waiting on Docker to run the local database and pass the "Done when" check |
| 1 — Database functions | Not started | 0001_init.sql and seed.sql provided |
| 2 — Menu, product, cart | Not started | |
| 3 — Checkout and tracking | Not started | |
| 4 — Staff screens | Not started | |
| 5 — Admin screens | Not started | |
| 6 — Launch | Not started | |
| 7 — After launch | Not started | |

## Phase 0 checklist

- [x] Expo app created (SDK 58, TypeScript, Expo Router); CLAUDE.md, docs/ and supabase/ kept
- [x] NativeWind, supabase-js, react-query, zustand + AsyncStorage, react-hook-form, zod, date-fns(-tz), ESLint + Prettier, jest-expo installed
- [x] `src/lib/supabase.ts`, providers in `app/_layout.tsx`, `.env.example`, npm scripts
- [x] `npx supabase init` done; 0001_init.sql and seed.sql unchanged (checksums match)
- [ ] `npx supabase start && npx supabase db reset` works — **not run: Docker is not installed**
- [x] Placeholder Home reads `settings.store_name` (tested against a stub API only, not a real database)
- [x] `app.json` web output `single`, `public/_redirects`, `eas.json`, `ci.yml`
- [x] PROGRESS.md entries
- [ ] Done when: web and Android show "RJL Lechunan" from the local DB — **not yet verified**

Passing now: typecheck, lint, jest (6 tests), expo-doctor (20/20), web and Android bundles, Home at 360 px in Chrome.

Deferred from the PLAN §4 `_layout.tsx` note: toasts (Phase 4, first used there); fonts need no provider because §9 uses system fonts.

## Needs action

- **Install Docker Desktop (blocks Phase 0 and Phase 1).** WSL is not enabled on this PC. In PowerShell as Administrator run `wsl --install`, restart, then install Docker Desktop.
- **Add table grants in Phase 1 (blocks production).** Supabase projects created since 30 May 2026 no longer give `anon`/`authenticated` automatic access to new tables, and 0001_init.sql has no `GRANT` statements. Local works because `auto_expose_new_tables` defaults to true. On a new cloud project every table read would fail with error 42501. `0002_functions.sql` must add explicit grants, and `auto_expose_new_tables = false` should be set in `supabase/config.toml` so local matches production.
- **Expo Go version.** The app uses SDK 58, but the Expo Go in the app stores is listed for SDK 57. Install Expo Go 58.0.5 from the APK link in the Expo release: https://github.com/expo/expo-go-releases/releases/download/Expo-Go-58.0.5/Expo-Go-58.0.5.apk
- **`npm run db:test` needs `psql`** on this PC. It is not installed yet; sort this out in Phase 1.

## Decisions needed from the owner

- Real sizes, kilo ranges and prices (seed has placeholders).
- Real freebie rules; should freebies stack?
- Downpayment: required for which orders? minimum amount? deadline?
- Daily roasting capacity and order lead time.
- Delivery areas and fee.
- Cancellation and refund rule.
- Logo and brand colours.

## Log

<!-- yyyy-mm-dd — what was done -->

2026-11-04 — Phase 0 code finished on Expo SDK 58. Local database not run because Docker is missing.
