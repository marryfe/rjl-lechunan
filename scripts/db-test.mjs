// Runs every supabase/tests/*.sql file against the local database.
// Uses psql if it is installed, otherwise the psql inside the Supabase Docker container.
// Usage: npm run db:test (after `npx supabase db reset`).
import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const testsDir = join('supabase', 'tests');
const dbUrl =
  process.env.SUPABASE_DB_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
const container = 'supabase_db_rjl-lechunan';

const files = existsSync(testsDir)
  ? readdirSync(testsDir)
      .filter((name) => name.endsWith('.sql') && !name.startsWith('_'))
      .sort()
  : [];

if (files.length === 0) {
  console.log('No SQL tests in supabase/tests yet.');
  process.exit(0);
}

const psqlFlags = ['-v', 'ON_ERROR_STOP=1', '-q', '-f', '-'];
const hasPsql = !spawnSync('psql', ['--version']).error;
const [command, args] = hasPsql
  ? ['psql', [dbUrl, ...psqlFlags]]
  : ['docker', ['exec', '-i', container, 'psql', '-U', 'postgres', '-d', 'postgres', ...psqlFlags]];

const helpers = readFileSync(join(testsDir, '_helpers.sql'), 'utf8');

for (const file of files) {
  console.log(`Running ${file}`);
  const sql = readFileSync(join(testsDir, file), 'utf8');
  const result = spawnSync(command, args, {
    input: `${helpers}\n${sql}`,
    stdio: ['pipe', 'inherit', 'inherit'],
  });
  if (result.error) {
    console.error(`Could not run ${command}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log(`All ${files.length} SQL test file(s) passed.`);
