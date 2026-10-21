import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { BOOKING_STATUSES } from '../src/booking.js';
import { DomainError } from '../src/errors.js';
import {
  intensityOf,
  isReviewable,
  REVIEW_HITS_MAX,
  reviewDocId,
  STUDIO_BRICK_REASONS,
  validateReviewInput,
} from '../src/review.js';

const prefixes = [
  'https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/',
  'http://127.0.0.1:9199/v0/b/demo-bucket/o/',
];

const validStoragePath = (callerId: string, postId: string, name = '0.jpg') =>
  `posts/${callerId}/${postId}/${name}`;

const validUrl = (callerId: string, postId: string, name = '0.jpg') =>
  `${prefixes[0]}${encodeURIComponent(validStoragePath(callerId, postId, name))}?alt=media`;

describe('intensityOf', () => {
  it('matches the spec table', () => {
    assert.equal(REVIEW_HITS_MAX, 10);
    const table: Array<[number, number]> = [
      [1, 0.4],
      [2, 0.58],
      [3, 0.69],
      [5, 0.82],
      [7, 0.91],
      [10, 1.0],
    ];
    for (const [hits, expected] of table) {
      assert.equal(intensityOf(hits), expected, `hits ${hits}`);
    }
  });

  it('refuses 0, 11, 2.5 and NaN with invalid_argument', () => {
    for (const bad of [0, 11, 2.5, NaN, -3]) {
      assert.throws(
        () => intensityOf(bad),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
        String(bad)
      );
    }
  });
});

describe('reviewDocId and isReviewable', () => {
  it('photographer uses the booking id, studio appends _studio', () => {
    assert.equal(reviewDocId('b1', 'photographer'), 'b1');
    assert.equal(reviewDocId('b1', 'studio'), 'b1_studio');
  });

  it('isReviewable is true for approved and completed', () => {
    for (const status of BOOKING_STATUSES) {
      assert.equal(isReviewable(status), status === 'approved' || status === 'completed', status);
    }
  });
});

describe('validateReviewInput', () => {
  it('accepts tomato x7 without reasons', () => {
    const res = validateReviewInput(
      { bookingId: 'book1', verdict: 'tomato', hits: 7, text: 'Buổi chụp rất tuyệt vời!' },
      'cust1',
      prefixes
    );
    assert.equal(res.verdict, 'tomato');
    assert.equal(res.hits, 7);
    assert.deepEqual(res.reasons, []);
  });

  it('accepts brick x3 with [late, slow_delivery]', () => {
    const res = validateReviewInput(
      {
        bookingId: 'book1',
        verdict: 'brick',
        hits: 3,
        reasons: ['late', 'slow_delivery'],
        text: 'Đến trễ và giao ảnh chậm',
      },
      'cust1',
      prefixes
    );
    assert.equal(res.verdict, 'brick');
    assert.deepEqual(res.reasons, ['late', 'slow_delivery']);
  });

  const invalid = (raw: Record<string, unknown>, label: string) =>
    assert.throws(
      () =>
        validateReviewInput(
          { bookingId: 'book1', text: 'Buổi chụp rất tuyệt vời!', ...raw },
          'cust1',
          prefixes
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      label
    );

  it('refuses an unknown verdict', () => {
    for (const bad of ['banana', 'TOMATO', null, undefined, 5]) {
      invalid({ verdict: bad, hits: 1 }, `verdict ${String(bad)}`);
    }
  });

  it('refuses hits 0, 11, 3.5 and "3"', () => {
    for (const bad of [0, 11, -1, 3.5, '3', null, undefined, NaN]) {
      invalid({ verdict: 'tomato', hits: bad }, `hits ${String(bad)}`);
    }
  });

  it('refuses brick without reasons', () => {
    invalid({ verdict: 'brick', hits: 2 }, 'missing');
    invalid({ verdict: 'brick', hits: 2, reasons: [] }, 'empty');
  });

  it('refuses brick with an unknown reason', () => {
    invalid({ verdict: 'brick', hits: 2, reasons: ['late', 'rude'] }, 'unknown');
    invalid({ verdict: 'brick', hits: 2, reasons: 'late' }, 'not an array');
  });

  it('refuses brick with a duplicate reason', () => {
    invalid({ verdict: 'brick', hits: 2, reasons: ['late', 'late'] }, 'duplicate');
  });

  it('refuses tomato with reasons', () => {
    invalid({ verdict: 'tomato', hits: 2, reasons: ['late'] }, 'tomato with reasons');
  });

  it('ignores a client intensity and a client rating', () => {
    const res = validateReviewInput(
      {
        bookingId: 'book1',
        verdict: 'tomato',
        hits: 2,
        intensity: 1,
        rating: 5,
        text: 'Buổi chụp rất tuyệt vời!',
      },
      'cust1',
      prefixes
    );
    assert.equal('intensity' in res, false);
    assert.equal('rating' in res, false);
  });

  it('text needs 10 to 1000 graphemes after trimming (emoji count as one)', () => {
    // Exactly 10 chars
    const minText = '1234567890';
    const res1 = validateReviewInput(
      { bookingId: 'book1', verdict: 'tomato', hits: 3, text: minText },
      'cust1',
      prefixes
    );
    assert.equal(res1.text, minText);

    // 10 emoji graphemes
    const emojiText = '📸✨🌟🎉🇻🇳👍❤️📷🌸🎯';
    const res2 = validateReviewInput(
      { bookingId: 'book1', verdict: 'tomato', hits: 3, text: emojiText },
      'cust1',
      prefixes
    );
    assert.equal(res2.text, emojiText);

    // Padding spaces trimmed before check
    const padded = '   1234567890   ';
    const res3 = validateReviewInput(
      { bookingId: 'book1', verdict: 'tomato', hits: 3, text: padded },
      'cust1',
      prefixes
    );
    assert.equal(res3.text, '1234567890');

    // 9 chars fails
    assert.throws(
      () =>
        validateReviewInput(
          { bookingId: 'book1', verdict: 'tomato', hits: 3, text: '123456789' },
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
          { bookingId: 'book1', verdict: 'tomato', hits: 3, text: longText },
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
            verdict: 'tomato', hits: 3,
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
            verdict: 'tomato', hits: 3,
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
            verdict: 'tomato', hits: 3,
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
            verdict: 'tomato', hits: 3,
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
            verdict: 'tomato', hits: 3,
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
        verdict: 'tomato', hits: 3,
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

describe('validateReviewInput studio block', () => {
  const base = { bookingId: 'book1', verdict: 'tomato', hits: 3, text: 'Buổi chụp rất ổn, cảm ơn!' };
  const studioBrick = { verdict: 'brick', hits: 2, reasons: ['slow_response'], text: 'Tư vấn trả lời chậm quá.' };
  const bad = (raw: unknown, studio: boolean) =>
    assert.throws(
      () => validateReviewInput(raw, 'cust1', prefixes, { studio }),
      (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument'
    );

  it('an individual booking accepts no studio block (invalid_argument)', () => {
    bad({ ...base, studio: studioBrick }, false);
    assert.equal(validateReviewInput(base, 'cust1', prefixes).studio, null);
  });

  it('a studio booking needs the studio block (invalid_argument without)', () => {
    bad(base, true);
    bad({ ...base, studio: 'x' }, true);
  });

  it('studio brick reasons are the five studio codes; a photographer code is invalid there', () => {
    assert.deepEqual(STUDIO_BRICK_REASONS, [
      'late_assignment',
      'slow_response',
      'price_changed',
      'poor_assignment',
      'other',
    ]);
    for (const code of STUDIO_BRICK_REASONS) {
      const out = validateReviewInput(
        { ...base, studio: { ...studioBrick, reasons: [code] } },
        'cust1',
        prefixes,
        { studio: true }
      );
      assert.deepEqual(out.studio?.reasons, [code]);
    }
    bad({ ...base, studio: { ...studioBrick, reasons: ['late'] } }, true);
    bad({ ...base, studio: { ...studioBrick, reasons: [] } }, true);
    bad({ ...base, studio: { ...studioBrick, reasons: ['other', 'other'] } }, true);
    // a studio code is not valid in the photographer block
    bad({ ...base, verdict: 'brick', reasons: ['slow_response'], studio: studioBrick }, true);
  });

  it('a studio tomato block with reasons is invalid', () => {
    bad({ ...base, studio: { ...studioBrick, verdict: 'tomato' } }, true);
    const ok = validateReviewInput(
      { ...base, studio: { ...studioBrick, verdict: 'tomato', reasons: [] } },
      'cust1',
      prefixes,
      { studio: true }
    );
    assert.equal(ok.studio?.verdict, 'tomato');
  });

  it('the studio block validates hits and text like the main block', () => {
    bad({ ...base, studio: { ...studioBrick, hits: 0 } }, true);
    bad({ ...base, studio: { ...studioBrick, hits: 11 } }, true);
    bad({ ...base, studio: { ...studioBrick, text: 'ngắn' } }, true);
  });
});
