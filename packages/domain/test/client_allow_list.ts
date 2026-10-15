// Test-only TypeScript port of the client's `isAllowedContactUri` (plan 2b, Task 4): the server
// must only ever build URLs that the app agrees to open.
const E164 = /^\+\d{8,15}$/;
const DIGITS_PATH = /^\/\d{8,15}$/;

export function isAllowedContactUrl(raw: string, channel: string): boolean {
  if (channel === 'call') return raw.startsWith('tel:') && E164.test(raw.slice('tel:'.length));
  const host = channel === 'zalo' ? 'zalo.me' : channel === 'whatsapp' ? 'wa.me' : null;
  if (host === null) return false;
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  return url.protocol === 'https:'
    && url.hostname === host
    && url.port === ''
    && url.username === ''
    && url.password === ''
    && url.search === ''
    && url.hash === ''
    && DIGITS_PATH.test(url.pathname);
}
