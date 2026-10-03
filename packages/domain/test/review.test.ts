import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { validateReviewInput } from '../src/review.js';

const prefixes = [
  'https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/',
  'http://127.0.0.1:9199/v0/b/demo-bucket/o/',
];

const validStoragePath = (callerId: string, postId: string, name = '0.jpg') =>
  `posts/${callerId}/${postId}/${name}`;

const validUrl = (callerId: string, postId: string, name = '0.jpg') =>
  `${prefixes[0]}${encodeURIComponent(validStoragePath(callerId, postId, name))}?alt=media`;

describe('validateReviewInput', () => {
  it('rating must be an integer from 1 to 5', () => {
    for (const rating of [1, 2, 3, 4, 5]) {
      const res = validateReviewInput(
        {
          bookingId: 'book1',
          rating,
          text: 'Buổi chụp rất tuyệt vời!',
        },
        'cust1',
        prefixes
      );
      assert.equal(res.rating, rating);
    }

    for (const bad of [0, 6, -1, 3.5, '5', null, undefined, NaN]) {
      assert.throws(
        () =>
          validateReviewInput(
            {
              bookingId: 'book1',
              rating: bad,
              text: 'Buổi chụp rất tuyệt vời!',
            },
            'cust1',
            prefixes
          ),
        (err: unknown) =>
          err instanceof DomainError && err.code === 'invalid_argument',
        `expected rating ${String(bad)} to fail`
      );
    }
  });

  it('text needs 10 to 1000 graphemes after trimming (emoji count as one)', () => {
    // Exactly 10 chars
    const minText = '1234567890';
    const res1 = validateReviewInput(
      { bookingId: 'book1', rating: 5, text: minText },
      'cust1',
      prefixes
    );
    assert.equal(res1.text, minText);

    // 10 emoji graphemes
    const emojiText = '📸✨🌟🎉🇻🇳👍❤️📷🌸🎯';
    const res2 = validateReviewInput(
      { bookingId: 'book1', rating: 5, text: emojiText },
      'cust1',
      prefixes
    );
    assert.equal(res2.text, emojiText);

    // Padding spaces trimmed before check
    const padded = '   1234567890   ';
    const res3 = validateReviewInput(
      { bookingId: 'book1', rating: 5, text: padded },
      'cust1',
      prefixes
    );
    assert.equal(res3.text, '1234567890');

    // 9 chars fails
    assert.throws(
      () =>
        validateReviewInput(
          { bookingId: 'book1', rating: 5, text: '123456789' },
          'cust1',
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );

    // > 1000 chars fails
    const longText = 'a'.repeat(1001);
    assert.throws(
      () =>
        validateReviewInput(
          { bookingId: 'book1', rating: 5, text: longText },
          'cust1',
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );
  });

  it("photo paths must be the caller's own post folder", () => {
    const callerId = 'cust1';
    const postId = 'post1';

    // Different user in path
    assert.throws(
      () =>
        validateReviewInput(
          {
            bookingId: 'book1',
            rating: 5,
            text: 'Chụp hình đẹp lắm nha',
            postId,
            photos: [
              {
                url: validUrl('otherUser', postId),
                storagePath: validStoragePath('otherUser', postId),
              },
            ],
          },
          callerId,
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );

    // Different postId in path
    assert.throws(
      () =>
        validateReviewInput(
          {
            bookingId: 'book1',
            rating: 5,
            text: 'Chụp hình đẹp lắm nha',
            postId,
            photos: [
              {
                url: validUrl(callerId, 'differentPost'),
                storagePath: validStoragePath(callerId, 'differentPost'),
              },
            ],
          },
          callerId,
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );
  });

  it('urls must match a configured storage prefix and the encoded path', () => {
    const callerId = 'cust1';
    const postId = 'post1';
    const path = validStoragePath(callerId, postId);

    // Unallowed domain
    assert.throws(
      () =>
        validateReviewInput(
          {
            bookingId: 'book1',
            rating: 5,
            text: 'Chụp hình đẹp lắm nha',
            postId,
            photos: [
              {
                url: `https://evil.com/${encodeURIComponent(path)}`,
                storagePath: path,
              },
            ],
          },
          callerId,
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );

    // Path mismatch between url and storagePath
    assert.throws(
      () =>
        validateReviewInput(
          {
            bookingId: 'book1',
            rating: 5,
            text: 'Chụp hình đẹp lắm nha',
            postId,
            photos: [
              {
                url: `${prefixes[0]}${encodeURIComponent(validStoragePath(callerId, postId, 'different.jpg'))}`,
                storagePath: path,
              },
            ],
          },
          callerId,
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );
  });

  it('more than 10 photos is invalid', () => {
    const callerId = 'cust1';
    const postId = 'post1';
    const photos = Array.from({ length: 11 }, (_, i) => ({
      url: validUrl(callerId, postId, `${i}.jpg`),
      storagePath: validStoragePath(callerId, postId, `${i}.jpg`),
    }));

    assert.throws(
      () =>
        validateReviewInput(
          {
            bookingId: 'book1',
            rating: 5,
            text: 'Chụp hình đẹp lắm nha',
            postId,
            photos,
          },
          callerId,
          prefixes
        ),
      (err: unknown) =>
        err instanceof DomainError && err.code === 'invalid_argument'
    );
  });

  it('no photos means postId is ignored', () => {
    const res = validateReviewInput(
      {
        bookingId: 'book1',
        rating: 5,
        text: 'Chụp hình đẹp lắm nha',
        postId: 'ignoredPostId',
        photos: [],
      },
      'cust1',
      prefixes
    );
    assert.equal(res.postId, null);
    assert.equal(res.photos.length, 0);
  });
});
