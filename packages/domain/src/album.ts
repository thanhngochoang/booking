import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export const ALBUM_TITLE_MAX = 40;
export const ALBUM_DESC_MAX = 300;
export const ALBUMS_PER_PHOTOGRAPHER = 30;
export const POSTS_PER_ALBUM = 200;
export const MOVE_BATCH_MAX = 50;

export interface AlbumCover {
  readonly postId: string;
  readonly imageIndex: number;
}

export interface Album {
  readonly id: string;
  readonly photographerId: string;
  readonly title: string;
  readonly titleKey: string;
  readonly description: string;
  readonly cover: AlbumCover | null;
  readonly position: number;
  readonly postCount: number;
  readonly mediaCount: number;
  readonly visible: boolean;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** The album-relevant slice of a post. */
export interface AlbumPost {
  readonly id: string;
  readonly authorId: string;
  readonly kind: string;
  readonly imageCount: number;
  readonly albumId: string | null;
  readonly albumPosition: number | null;
}

/** Trim, collapse runs of whitespace, lower-case (locale-insensitive). */
export function titleKeyOf(title: string): string {
  return title.normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase();
}

function cleanTitle(v: unknown): string {
  if (typeof v !== 'string') throw new DomainError('invalid_argument');
  const t = v.normalize('NFC').trim().replace(/\s+/g, ' ');
  const n = graphemeCount(t);
  if (n < 1 || n > ALBUM_TITLE_MAX) throw new DomainError('invalid_argument');
  return t;
}

function cleanDescription(v: unknown): string {
  if (typeof v !== 'string') throw new DomainError('invalid_argument');
  const d = v.trim();
  if (graphemeCount(d) > ALBUM_DESC_MAX) throw new DomainError('invalid_argument');
  return d;
}

function cleanCover(v: unknown): AlbumCover | null {
  if (v === null) return null;
  if (typeof v !== 'object') throw new DomainError('invalid_argument');
  const { postId, imageIndex } = v as { postId?: unknown; imageIndex?: unknown };
  if (!isId(postId)) throw new DomainError('invalid_argument');
  if (typeof imageIndex !== 'number' || !Number.isInteger(imageIndex) || imageIndex < 0) {
    throw new DomainError('invalid_argument');
  }
  return { postId, imageIndex };
}

/**
 * Validates the editable fields. Full (`partial = false`): the title is required.
 * Partial: only the fields present are checked and returned.
 */
export function validateAlbumFields(
  raw: unknown,
  partial: boolean,
): { title?: string; description?: string; cover?: AlbumCover | null } {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const r = raw as { title?: unknown; description?: unknown; cover?: unknown };
  const out: { title?: string; description?: string; cover?: AlbumCover | null } = {};
  if (r.title !== undefined || !partial) out.title = cleanTitle(r.title);
  if (r.description !== undefined) out.description = cleanDescription(r.description);
  if (r.cover !== undefined) out.cover = cleanCover(r.cover);
  return out;
}
