import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { ApiError, friendlyError } from '../errors';
import { strings } from '../strings';

describe('ApiError', () => {
  it('reads the code and detail from a Postgres message', () => {
    const error = new ApiError('CAPACITY_FULL: this date is fully booked');
    expect(error.code).toBe('CAPACITY_FULL');
    expect(error.detail).toBe('this date is fully booked');
  });

  it('leaves the code empty for anything else', () => {
    expect(new ApiError('permission denied for table orders').code).toBeNull();
    expect(new ApiError('NOT_A_REAL_CODE: nope').code).toBeNull();
    expect(new ApiError('TypeError: Failed to fetch').code).toBeNull();
  });
});

describe('friendlyError', () => {
  it('uses the friendly text', () => {
    expect(friendlyError(new ApiError('RATE_LIMIT: too many orders'))).toBe(
      strings.errors.RATE_LIMIT,
    );
  });

  it('adds the detail where it helps', () => {
    expect(
      friendlyError(new ApiError('NOT_ENOUGH_STOCK: Pig - Large (~25 kg) (need 2, have 1)')),
    ).toBe('Not enough stock. (Pig - Large (~25 kg) (need 2, have 1))');
  });

  it('never shows a raw database or network error', () => {
    const unknown = strings.errors.UNKNOWN;
    expect(friendlyError(new ApiError('permission denied for table orders'))).toBe(unknown);
    expect(friendlyError(new Error('duplicate key value'))).toBe(unknown);
    expect(friendlyError('oops')).toBe(unknown);
  });
});

describe('error codes', () => {
  const migration = readFileSync(
    join(__dirname, '../../../supabase/migrations/0002_functions.sql'),
    'utf8',
  );
  const raised = [...migration.matchAll(/raise exception '([A-Z_]+):/g)].map((match) => match[1]);

  it('finds the codes in the migration', () => {
    expect(new Set(raised).size).toBeGreaterThan(25);
  });

  it('has friendly text for every code the database raises', () => {
    const missing = [...new Set(raised)].filter((code) => !(code in strings.errors));
    expect(missing).toEqual([]);
  });

  it('has no friendly text for codes the database no longer raises', () => {
    const unused = Object.keys(strings.errors).filter(
      (code) => code !== 'UNKNOWN' && !raised.includes(code),
    );
    expect(unused).toEqual([]);
  });
});
