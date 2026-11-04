// Runs every supabase/tests/*.sql file against the local database with psql.
// Usage: npm run db:test (after `npx supabase db reset`).
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const testsDir = join('supabase', 'tests');
const dbUrl =
  process.env.SUPABASE_DB_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

const files = existsSync(testsDir)
  ? readdirSync(testsDir)
      .filter((name) => name.endsWith('.sql'))
      .sort()
  : [];

if (files.length === 0) {
  console.log('No SQL tests in supabase/tests yet.');
  process.exit(0);
}

for (const file of files) {
  console.log(`Running ${file}`);
  const result = spawnSync(
    'psql',
    [dbUrl, '-v', 'ON_ERROR_STOP=1', '-q', '-f', join(testsDir, file)],
    { stdio: 'inherit' },
  );
  if (result.error) {
    console.error(`Could not run psql: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log(`All ${files.length} SQL test file(s) passed.`);
