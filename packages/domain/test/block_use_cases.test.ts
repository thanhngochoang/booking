import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { blockUser, unblockUser } from '../src/block_use_cases.js';
import { MAX_BLOCKS } from '../src/block.js';
import { DomainError } from '../src/errors.js';
import { createSafetyWorld } from './support/safety_world.js';
import { chatIdFor } from '../src/chat.js';

describe('block_use_cases', () => {
  it('MemoryBlockStore as a BlockGate sees a block written by blockUser and forgets it after unblockUser', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    profiles.setProfile('user_b', 'Bình', 'https://avatar.test/b.jpg');

    assert.equal(await blockStore.isBlockedEitherWay('user_a', 'user_b'), false);
    assert.equal(await blockStore.isBlockedEitherWay('user_b', 'user_a'), false);

    await blockUser(blockDeps, 'user_a', { userId: 'user_b' });

    assert.equal(await blockStore.isBlockedEitherWay('user_a', 'user_b'), true);
    assert.equal(await blockStore.isBlockedEitherWay('user_b', 'user_a'), true);

    await unblockUser(blockDeps, 'user_a', { userId: 'user_b' });

    assert.equal(await blockStore.isBlockedEitherWay('user_a', 'user_b'), false);
    assert.equal(await blockStore.isBlockedEitherWay('user_b', 'user_a'), false);
  });

  it('block writes the record with name and avatar, both indexes, and blockedAt on both existing chat orientations', async () => {
    const { blockDeps, blockStore, profiles, clock } = createSafetyWorld();
    profiles.setProfile('user_b', 'Bình', 'https://avatar.test/b.jpg');

    const chat1 = chatIdFor('user_a', 'user_b');
    const chat2 = chatIdFor('user_b', 'user_a');
    blockStore.chats.set(chat1, { exists: true, blockedAt: null });
    blockStore.chats.set(chat2, { exists: true, blockedAt: null });

    const rec = await blockUser(blockDeps, 'user_a', { userId: 'user_b', source: 'menu' });

    assert.equal(rec.blockerId, 'user_a');
    assert.equal(rec.blockedId, 'user_b');
    assert.equal(rec.blockedName, 'Bình');
    assert.equal(rec.blockedAvatarUrl, 'https://avatar.test/b.jpg');
    assert.equal(rec.source, 'menu');
    assert.equal(rec.createdAt, clock.now().toISOString());

    const mine = await blockStore.indexes.get('user_a');
    const theirs = await blockStore.indexes.get('user_b');
    assert.deepEqual(mine?.blockedIds, ['user_b']);
    assert.deepEqual(mine?.blockedByIds, []);
    assert.deepEqual(theirs?.blockedIds, []);
    assert.deepEqual(theirs?.blockedByIds, ['user_a']);

    assert.equal(blockStore.chats.get(chat1)?.blockedAt, clock.now().toISOString());
    assert.equal(blockStore.chats.get(chat2)?.blockedAt, clock.now().toISOString());
  });

  it('block deletes follows and saved-photographer markers both ways', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    profiles.setProfile('user_b', 'Bình');

    blockStore.followMarkers.add('follows:user_a_user_b');
    blockStore.followMarkers.add('follows:user_b_user_a');
    blockStore.followMarkers.add('savedPhotographers:user_a_user_b');
    blockStore.followMarkers.add('savedPhotographers:user_b_user_a');
    blockStore.followMarkers.add('follows:user_a_user_c');

    await blockUser(blockDeps, 'user_a', { userId: 'user_b' });

    assert.equal(blockStore.followMarkers.has('follows:user_a_user_b'), false);
    assert.equal(blockStore.followMarkers.has('follows:user_b_user_a'), false);
    assert.equal(blockStore.followMarkers.has('savedPhotographers:user_a_user_b'), false);
    assert.equal(blockStore.followMarkers.has('savedPhotographers:user_b_user_a'), false);
    assert.equal(blockStore.followMarkers.has('follows:user_a_user_c'), true);
  });

  it('blocking twice changes nothing', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    profiles.setProfile('user_b', 'Bình');

    const rec1 = await blockUser(blockDeps, 'user_a', { userId: 'user_b' });
    const rec2 = await blockUser(blockDeps, 'user_a', { userId: 'user_b' });

    assert.deepEqual(rec1, rec2);
    assert.equal(blockStore.blocks.size, 1);
  });

  it('blocking yourself → invalid_argument; an unknown user → not_found', async () => {
    const { blockDeps, profiles } = createSafetyWorld();
    profiles.setProfile('user_b', 'Bình');

    await assert.rejects(
      () => blockUser(blockDeps, 'user_a', { userId: 'user_a' }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    await assert.rejects(
      () => blockUser(blockDeps, 'user_a', { userId: 'unknown_user' }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_found',
    );
  });

  it('the 501st block → limit_exceeded', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    const blockedList: string[] = [];
    for (let i = 0; i < MAX_BLOCKS; i++) {
      blockedList.push(`user_${i}`);
    }
    blockStore.indexes.set('user_a', { blockedIds: blockedList, blockedByIds: [] });
    profiles.setProfile('user_new', 'New');

    await assert.rejects(
      () => blockUser(blockDeps, 'user_a', { userId: 'user_new' }),
      (err: unknown) => err instanceof DomainError && err.code === 'limit_exceeded',
    );
  });

  it('unblock removes the record and both index entries and clears blockedAt', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    profiles.setProfile('user_b', 'Bình');
    const chat1 = chatIdFor('user_a', 'user_b');
    blockStore.chats.set(chat1, { exists: true, blockedAt: null });

    await blockUser(blockDeps, 'user_a', { userId: 'user_b' });
    assert.equal(blockStore.blocks.size, 1);
    assert.ok(blockStore.chats.get(chat1)?.blockedAt);

    await unblockUser(blockDeps, 'user_a', { userId: 'user_b' });
    assert.equal(blockStore.blocks.size, 0);
    assert.deepEqual(blockStore.indexes.get('user_a')?.blockedIds, []);
    assert.deepEqual(blockStore.indexes.get('user_b')?.blockedByIds, []);
    assert.equal(blockStore.chats.get(chat1)?.blockedAt, null);
  });

  it('mutual block: one unblock keeps the chat blocked and both still hidden', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    profiles.setProfile('user_a', 'An');
    profiles.setProfile('user_b', 'Bình');
    const chat1 = chatIdFor('user_a', 'user_b');
    blockStore.chats.set(chat1, { exists: true, blockedAt: null });

    // Both block each other
    await blockUser(blockDeps, 'user_a', { userId: 'user_b' });
    await blockUser(blockDeps, 'user_b', { userId: 'user_a' });

    // User A unblocks User B
    await unblockUser(blockDeps, 'user_a', { userId: 'user_b' });

    // Chat must still be blocked because B still blocks A
    assert.ok(blockStore.chats.get(chat1)?.blockedAt);

    // User A's index still has blockedByIds containing user_b
    assert.deepEqual(blockStore.indexes.get('user_a')?.blockedByIds, ['user_b']);
    assert.deepEqual(blockStore.indexes.get('user_b')?.blockedIds, ['user_a']);
    assert.equal(await blockStore.isBlockedEitherWay('user_a', 'user_b'), true);
  });

  it('unblocking someone not blocked is a no-op', async () => {
    const { blockDeps } = createSafetyWorld();
    await assert.doesNotThrow(() => unblockUser(blockDeps, 'user_a', { userId: 'user_b' }));
  });
});
