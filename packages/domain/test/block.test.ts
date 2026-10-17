import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  blockedEitherWay,
  EMPTY_BLOCK_INDEX,
  withBlock,
  withoutBlock,
  type BlockIndex,
} from '../src/block.js';

describe('block model and helpers', () => {
  it('withBlock/withoutBlock keep set semantics', () => {
    let idx: BlockIndex = EMPTY_BLOCK_INDEX;

    // Add blocked
    idx = withBlock(idx, 'user_b', 'blocked');
    assert.deepEqual(idx.blockedIds, ['user_b']);
    assert.deepEqual(idx.blockedByIds, []);

    // Duplicate add does not duplicate
    idx = withBlock(idx, 'user_b', 'blocked');
    assert.deepEqual(idx.blockedIds, ['user_b']);

    // Add another
    idx = withBlock(idx, 'user_c', 'blocked');
    assert.deepEqual(idx.blockedIds, ['user_b', 'user_c']);

    // Add blockedBy
    idx = withBlock(idx, 'user_d', 'blockedBy');
    assert.deepEqual(idx.blockedIds, ['user_b', 'user_c']);
    assert.deepEqual(idx.blockedByIds, ['user_d']);

    // Duplicate blockedBy
    idx = withBlock(idx, 'user_d', 'blockedBy');
    assert.deepEqual(idx.blockedByIds, ['user_d']);

    // withoutBlock removes properly
    idx = withoutBlock(idx, 'user_b', 'blocked');
    assert.deepEqual(idx.blockedIds, ['user_c']);

    // removing non-existent is no-op
    const unchanged = withoutBlock(idx, 'user_not_there', 'blocked');
    assert.deepEqual(unchanged, idx);

    // remove blockedBy
    idx = withoutBlock(idx, 'user_d', 'blockedBy');
    assert.deepEqual(idx.blockedByIds, []);
  });

  it('blockedEitherWay checks both arrays', () => {
    const idx: BlockIndex = {
      blockedIds: ['user_b'],
      blockedByIds: ['user_c'],
    };

    assert.equal(blockedEitherWay(idx, 'user_b'), true);
    assert.equal(blockedEitherWay(idx, 'user_c'), true);
    assert.equal(blockedEitherWay(idx, 'user_d'), false);
  });
});
