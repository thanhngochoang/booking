import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  BADGE_CATALOG,
  eligibleBadges,
  meets,
  planBadges,
  progressOf,
  snapshotText,
  type BadgeDefinition,
} from '../src/badge.js';

const badge = (id: string): BadgeDefinition => {
  const b = BADGE_CATALOG.find((x) => x.id === id);
  assert.ok(b, id);
  return b;
};

describe('badge catalogue', () => {
  it('catalogue has 12 badges, 3 from reviews and 9 system, unique ids and orders', () => {
    assert.equal(BADGE_CATALOG.length, 12);
    assert.equal(BADGE_CATALOG.filter((b) => b.source === 'review').length, 3);
    assert.equal(BADGE_CATALOG.filter((b) => b.source === 'system').length, 9);
    assert.equal(new Set(BADGE_CATALOG.map((b) => b.id)).size, 12);
    assert.equal(new Set(BADGE_CATALOG.map((b) => b.order)).size, 12);
    const orders = BADGE_CATALOG.map((b) => b.order);
    assert.deepEqual(orders, [...orders].sort((a, b) => a - b));
  });

  it('top_rated needs 20 reviews even at 5 stars', () => {
    const rule = badge('top_rated').rule;
    assert.equal(meets(rule, { rating: 5, reviewCount: 19 }), false);
    assert.equal(meets(rule, { rating: 5, reviewCount: 20 }), true);
    assert.equal(meets(rule, { rating: 4.7, reviewCount: 50 }), false);
    assert.equal(meets(rule, { rating: 4.8, reviewCount: 20 }), true);
  });

  it('top_rated progress counts reviews toward 20', () => {
    assert.deepEqual(progressOf(badge('top_rated'), { rating: 5, reviewCount: 12 }), { current: 12, target: 20 });
    assert.deepEqual(progressOf(badge('top_rated'), {}), { current: 0, target: 20 });
  });

  it('unknown responseMinutes never meets fast_reply', () => {
    const rule = badge('fast_reply').rule;
    assert.equal(meets(rule, {}), false);
    assert.equal(meets(rule, { responseMinutes: null }), false);
    assert.equal(meets(rule, { responseMinutes: 45 }), true);
    assert.equal(meets(rule, { responseMinutes: 61 }), false);
  });

  it('new_member is for the first 30 days only', () => {
    assert.equal(meets(badge('new_member').rule, { accountAgeDays: 30 }), true);
    assert.equal(meets(badge('new_member').rule, { accountAgeDays: 31 }), false);
  });

  it('complete_profile needs 6 work posts and an active service', () => {
    const rule = badge('complete_profile').rule;
    assert.equal(meets(rule, { workPosts: 6, activeServices: 0 }), false);
    assert.equal(meets(rule, { workPosts: 6, activeServices: 1 }), true);
    assert.equal(meets(rule, { workPosts: 5, activeServices: 3 }), false);
  });

  it('shoots progress caps at the target', () => {
    assert.deepEqual(progressOf(badge('shoots_10'), { completedShoots: 4 }), { current: 4, target: 10 });
    assert.deepEqual(progressOf(badge('shoots_10'), { completedShoots: 70 }), { current: 10, target: 10 });
  });

  it('customers are not eligible for photographer badges', () => {
    const ids = eligibleBadges(false).map((b) => b.id);
    assert.deepEqual(ids, ['detailed_reviewer', 'new_member', 'loyal_customer', 'sharer']);
    assert.equal(eligibleBadges(true).length, 12);
  });
});

describe('planBadges', () => {
  const photographer = eligibleBadges(true);

  it('planBadges awards newly met badges', () => {
    const plan = planBadges(photographer, { accountAgeDays: 3, completedShoots: 10 }, new Set());
    assert.deepEqual(plan.award.map((b) => b.id), ['new_member', 'shoots_10']);
    assert.deepEqual(plan.revoke, []);
  });

  it('planBadges revokes only revocable badges', () => {
    const plan = planBadges(photographer, { rating: 4.0, reviewCount: 30 }, new Set(['top_rated']));
    assert.deepEqual(plan.revoke, ['top_rated']);
    assert.deepEqual(plan.award, []);
  });

  it('planBadges never revokes shoots_10', () => {
    const plan = planBadges(photographer, { completedShoots: 0 }, new Set(['shoots_10', 'punctual']));
    assert.deepEqual(plan.revoke, []);
  });

  it('a badge already earned and still met is left alone', () => {
    const plan = planBadges(photographer, { completedShoots: 12 }, new Set(['shoots_10']));
    assert.deepEqual(plan.award.map((b) => b.id), []);
  });

  it("progress is omitted for earned and for progress 'none'", () => {
    const plan = planBadges(
      photographer,
      { completedShoots: 12, workPosts: 2, reviewCount: 5, rating: 5, accountAgeDays: 90 },
      new Set(['shoots_10']),
    );
    assert.equal('shoots_10' in plan.progress, false);
    assert.equal('new_member' in plan.progress, false);
    assert.equal('fast_reply' in plan.progress, false);
    assert.deepEqual(plan.progress.shoots_50, { current: 12, target: 50 });
    assert.deepEqual(plan.progress.complete_profile, { current: 2, target: 6 });
    assert.deepEqual(plan.progress.top_rated, { current: 5, target: 20 });
  });

  it('a just-awarded badge has no progress entry', () => {
    const plan = planBadges(photographer, { completedShoots: 10 }, new Set());
    assert.equal('shoots_10' in plan.progress, false);
  });
});

describe('snapshotText', () => {
  it("snapshot for top_rated reads '4,9 sao từ 58 đánh giá'", () => {
    assert.equal(snapshotText(badge('top_rated'), { rating: 4.9, reviewCount: 58 }), '4,9 sao từ 58 đánh giá');
  });

  it('shoots read the real count and others the description', () => {
    assert.equal(snapshotText(badge('shoots_100'), { completedShoots: 112 }), 'Hoàn thành 112 buổi');
    assert.equal(snapshotText(badge('punctual'), {}), '5 đánh giá khen đúng giờ');
  });
});
