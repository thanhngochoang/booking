import { formatVnDate } from './booking_policy.js';

export const HASHTAG_MAX = 40;
const BASE_MAX = 36;

/** NFD, drop combining marks, `đ → d`, `Đ → D`. */
export function foldVietnamese(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D');
}

/** `Photo walk phố cổ` on 20/10 → `PhotoWalkPhoCo1020` (day is read in Vietnam time). */
export function hashtagBase(title: string, day: Date): string {
  const words = foldVietnamese(title)
    .split(/[^A-Za-z0-9]+/)
    .filter((w) => w.length > 0)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
  let base = words.join('').slice(0, BASE_MAX);
  if (base.length === 0) base = 'Event';
  const [, mm, dd] = formatVnDate(day).split('-');
  return `${base}${mm ?? '00'}${dd ?? '00'}`;
}

/** `tag`, then `tag2`, `tag3`, …, always cut so the result stays within 40 characters. */
export function hashtagWithSuffix(tag: string, n: number): string {
  if (n <= 1) return tag;
  const suffix = String(n);
  return tag.slice(0, HASHTAG_MAX - suffix.length) + suffix;
}

export const hashtagKeyOf = (tag: string): string => tag.toLowerCase();

export const isValidHashtag = (tag: string): boolean => /^[A-Za-z0-9]{3,40}$/.test(tag);
