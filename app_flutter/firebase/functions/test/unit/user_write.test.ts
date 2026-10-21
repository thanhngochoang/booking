import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { handleUserWrite } from '../../src/triggers/user_write.js';
import { healNameKey } from '../../src/triggers/photographer_write.js';
import { FirestoreNameKeys } from '../../src/infra/studio_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { seedPerson } from './support/studio_fixtures.js';

function world() {
  const db = new MemoryFirestore();
  seedPerson(db, 'p1', 'Hồng Nhung');
  seedPerson(db, 'c1', 'Lan', null);
  return { db, keys: new FirestoreNameKeys(db.asFirestore()) };
}

describe('onUserWrite (S26.02 nameKey, Decision 19)', () => {
  it('onUserWrite writes nameKey only when displayName changes and a photographer doc exists', async () => {
    const { db, keys } = world();
    const writes = () => db.log.filter((w) => w.path === 'photographers/p1').length;

    assert.equal(
      await handleUserWrite({ uid: 'p1', before: { displayName: 'Hồng Nhung' }, after: { displayName: 'Hồng Nhung', bio: 'x' } }, keys),
      'unchanged',
    );
    assert.equal(writes(), 0);

    assert.equal(
      await handleUserWrite({ uid: 'p1', before: { displayName: 'Hồng Nhung' }, after: { displayName: 'Đặng Quốc Bảo' } }, keys),
      'written',
    );
    assert.equal(db.data('photographers/p1')?.nameKey, 'dang quoc bao');

    assert.equal(
      await handleUserWrite({ uid: 'c1', before: { displayName: 'Lan' }, after: { displayName: 'Lan Chi' } }, keys),
      'no_photographer',
    );
    assert.equal(db.data('photographers/c1'), undefined);

    assert.equal(await handleUserWrite({ uid: 'p1', before: { displayName: 'A' }, after: undefined }, keys), 'unchanged');
  });

  it('a created user document with a name keys an existing photographer', async () => {
    const { db, keys } = world();
    assert.equal(await handleUserWrite({ uid: 'p1', before: undefined, after: { displayName: 'Thu Hà' } }, keys), 'written');
    assert.equal(db.data('photographers/p1')?.nameKey, 'thu ha');
  });
});

describe('onPhotographerWrite nameKey heal', () => {
  it('onPhotographerWrite heals a missing nameKey once', async () => {
    const { db, keys } = world();
    const doc = db.data('photographers/p1');
    assert.equal(await healNameKey({ uid: 'p1', before: undefined, after: doc }, keys), 'written');
    assert.equal(db.data('photographers/p1')?.nameKey, 'hong nhung');
    // The heal's own write fires the trigger again: the key is there, nothing more is read or written.
    const after = db.data('photographers/p1');
    db.reads = 0;
    const logged = db.log.length;
    assert.equal(await healNameKey({ uid: 'p1', before: doc, after }, keys), 'present');
    assert.equal(db.reads, 0);
    assert.equal(db.log.length, logged);
    assert.equal(await healNameKey({ uid: 'p1', before: after, after: undefined }, keys), 'deleted');
  });

  it('a photographer without a users name gets an empty key (still healed only once)', async () => {
    const db = new MemoryFirestore();
    db.seed('photographers/p2', { onboardingComplete: true });
    const keys = new FirestoreNameKeys(db.asFirestore());
    assert.equal(await healNameKey({ uid: 'p2', before: undefined, after: db.data('photographers/p2') }, keys), 'written');
    assert.equal(db.data('photographers/p2')?.nameKey, '');
    assert.equal(await healNameKey({ uid: 'p2', before: undefined, after: db.data('photographers/p2') }, keys), 'present');
  });
});
