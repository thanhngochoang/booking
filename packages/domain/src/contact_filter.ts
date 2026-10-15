// Contact leak filter (job posts plan Decision 15): no phone, e-mail or link in free text, so contact
// stays inside the app until payment. Money like "1.000.000.000₫" is removed first so prices never
// read as phone numbers; digits may be split by spaces, dots, dashes or brackets.
const MONEY = /\d{1,3}(?:[.,]\d{3})+\s*(?:₫|đ|vnđ|vnd)/gi;
const PHONE = /(?:\+?84|0)(?:[\s.\-()]*\d){8,10}(?!\d)/;
const LONG_DIGITS = /(?:\d[\s.\-()]*){9,}/;
const EMAIL = /[^\s@]+@[^\s@]+\.[a-z]{2,}/i;
const LINK =
  /(https?:\/\/|www\.|\b(?:zalo\.me|fb\.com|facebook\.com|m\.me|t\.me)\b|\b[a-z0-9-]+\.(?:vn|com|me|net|org|io|link|ly)\b)/i;
const ZALO = /\bzalo\b/i;

export function findContactLeak(text: string): 'phone' | 'email' | 'link' | 'zalo' | null {
  const t = text.replace(MONEY, ' ');
  if (EMAIL.test(t)) return 'email';
  if (LINK.test(t)) return 'link';
  if (PHONE.test(t) || LONG_DIGITS.test(t)) return 'phone';
  if (ZALO.test(t)) return 'zalo';
  return null;
}
