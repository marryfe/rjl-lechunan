import { resolveSupabaseUrl } from '../supabase-url';

describe('resolveSupabaseUrl', () => {
  it('swaps 127.0.0.1 for the dev server address', () => {
    expect(resolveSupabaseUrl('http://127.0.0.1:54321', '192.168.1.20:8081')).toBe(
      'http://192.168.1.20:54321',
    );
  });

  it('swaps localhost for the dev server address', () => {
    expect(resolveSupabaseUrl('http://localhost:54321', '192.168.1.20:8081')).toBe(
      'http://192.168.1.20:54321',
    );
  });

  it('never changes a hosted project URL', () => {
    const url = 'https://abc.supabase.co';
    expect(resolveSupabaseUrl(url, '192.168.1.20:8081')).toBe(url);
  });

  it('leaves the URL alone without a usable dev host', () => {
    const url = 'http://127.0.0.1:54321';
    expect(resolveSupabaseUrl(url, null)).toBe(url);
    expect(resolveSupabaseUrl(url, undefined)).toBe(url);
    expect(resolveSupabaseUrl(url, '127.0.0.1:8081')).toBe(url);
    expect(resolveSupabaseUrl(url, 'abc-anonymous-8081.exp.direct')).toBe(url);
  });
});
