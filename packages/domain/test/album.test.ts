import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { titleKeyOf, validateAlbumFields } from '../src/album.js';
import { DomainError } from '../src/errors.js';

const bad = (fn: () => unknown): void =>
  assert.throws(fn, (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument');

describe('album fields', () => {
  it('title is trimmed and 1–40 characters', () => {
    assert.equal(validateAlbumFields({ title: '  Cưới  ' }, false).title, 'Cưới');
    assert.equal(validateAlbumFields({ title: 'a'.repeat(40) }, false).title?.length, 40);
    bad(() => validateAlbumFields({ title: '   ' }, false));
    bad(() => validateAlbumFields({ title: 'a'.repeat(41) }, false));
    bad(() => validateAlbumFields({}, false));
    bad(() => validateAlbumFields({ title: 5 }, true));
    assert.deepEqual(validateAlbumFields({}, true), {});
  });

  it('title key ignores case and extra spaces', () => {
    assert.equal(titleKeyOf('  Đám   CƯỚI '), titleKeyOf('đám cưới'));
    assert.equal(titleKeyOf('A  b'), 'a b');
  });

  it('description over 300 is invalid', () => {
    assert.equal(validateAlbumFields({ title: 'x', description: 'd'.repeat(300) }, false).description?.length, 300);
    bad(() => validateAlbumFields({ title: 'x', description: 'd'.repeat(301) }, false));
  });

  it('cover needs a post id and a non-negative index', () => {
    assert.deepEqual(validateAlbumFields({ cover: { postId: 'p1', imageIndex: 0 } }, true).cover, {
      postId: 'p1',
      imageIndex: 0,
    });
    assert.equal(validateAlbumFields({ cover: null }, true).cover, null);
    bad(() => validateAlbumFields({ cover: { postId: 'a/b', imageIndex: 0 } }, true));
    bad(() => validateAlbumFields({ cover: { postId: 'p1', imageIndex: -1 } }, true));
    bad(() => validateAlbumFields({ cover: { postId: 'p1', imageIndex: 1.5 } }, true));
    bad(() => validateAlbumFields({ cover: 'x' }, true));
  });
});
