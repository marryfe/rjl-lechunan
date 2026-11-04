const LOOPBACK_URL = /^(https?:\/\/)(?:127\.0\.0\.1|localhost)(?=[:/]|$)/;
const IPV4_HOST = /^\d{1,3}(?:\.\d{1,3}){3}$/;

/**
 * A phone cannot reach the PC's local database at 127.0.0.1, because that address means the phone
 * itself. During development, swap it for the address the phone already uses for the Expo server.
 * `devHostUri` looks like "192.168.1.20:8081". Tunnel hosts are left alone.
 */
export function resolveSupabaseUrl(url: string, devHostUri?: string | null): string {
  const host = devHostUri?.split(':')[0];
  if (!host || !IPV4_HOST.test(host) || host === '127.0.0.1') return url;
  return url.replace(LOOPBACK_URL, `$1${host}`);
}
