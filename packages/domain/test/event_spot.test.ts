import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { EMPTY_SPOT_STATS, type Spot } from '../src/spot.js';
import { publishEvent, saveEventDraft, updateEvent } from '../src/event_use_cases.js';
import { createEventWorld, eventRecord, ph1, publishedEvent, rawEvent, type EventWorld } from './support/event_world.js';

const rejects = (code: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === code && (field === undefined || e.field === field);

const spot = (id: string, over: Partial<Spot> = {}): Spot => ({
  id, name: 'Hồ Gươm', city: 'Hà Nội', areaCode: 'hn', point: { lat: 21.0285, lng: 105.8542 }, geohash: 'w7er8',
  radiusM: 500, cover: null, description: '', tips: [], seasonMonths: [], pinned: false, hidden: false,
  status: 'active', hotScore: 0, stats: EMPTY_SPOT_STATS, createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-01T00:00:00.000Z', rankedAt: null, updatedBy: 'staff', ...over,
});

const ID = 'ev1_aaaaaaaaaaaaaaaaaaaa';

function world(): EventWorld {
  const w = createEventWorld();
  w.store.spots.set('hoguom', spot('hoguom'));
  w.store.spots.set('hotay', spot('hotay', { point: { lat: 21.05, lng: 105.82 } })); // ~4 km away
  w.store.spots.set('old', spot('old', { status: 'archived' }));
  return w;
}

describe('event spot tag (S12.01, Decision 14)', () => {
  test('a draft with spotId null saves', async () => {
    const w = world();
    await saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: null }));
    assert.equal(w.store.events.get(ID)?.spotId, null);
  });

  test('publish with an active spot covering the location stores spotId', async () => {
    const w = world();
    const id = await publishedEvent(w, { spotId: 'hoguom' });
    assert.equal(w.store.events.get(id)?.spotId, 'hoguom');
  });

  test('a spot 3 km away is invalid_argument field spotId', async () => {
    const w = world();
    await assert.rejects(saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: 'hotay' })), rejects('invalid_argument', 'spotId'));
  });

  test('a spot inside radius plus slack is accepted', async () => {
    const w = world();
    // ~0.0063 deg lat is ~700 m north: beyond 500 m, within 500 + 500.
    w.store.spots.set('near', spot('near', { point: { lat: 21.0348, lng: 105.8542 } }));
    await saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: 'near' }));
    assert.equal(w.store.events.get(ID)?.spotId, 'near');
  });

  test('an archived spot is spot_archived', async () => {
    const w = world();
    await assert.rejects(saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: 'old' })), rejects('spot_archived'));
  });

  test('an unknown spot is not_found field spotId', async () => {
    const w = world();
    await assert.rejects(saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: 'nope' })), rejects('not_found', 'spotId'));
  });

  test('a non-string spotId is invalid_argument', async () => {
    const w = world();
    await assert.rejects(saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: 5 })), rejects('invalid_argument', 'spotId'));
  });

  test('updateEvent changes spotId', async () => {
    const w = world();
    const id = await publishedEvent(w, { spotId: 'hoguom' });
    await updateEvent(w.deps, ph1, { eventId: id, spotId: null });
    assert.equal(w.store.events.get(id)?.spotId, null);
    await updateEvent(w.deps, ph1, { eventId: id, spotId: 'hoguom' });
    assert.equal(w.store.events.get(id)?.spotId, 'hoguom');
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: id, spotId: 'hotay' }), rejects('invalid_argument', 'spotId'));
  });

  test('an old tag of a later archived spot does not block other edits', async () => {
    const w = world();
    const id = await publishedEvent(w, { spotId: 'hoguom' });
    w.store.spots.set('hoguom', spot('hoguom', { status: 'archived' }));
    await updateEvent(w.deps, ph1, { eventId: id, title: 'Tên mới' });
    assert.equal(w.store.events.get(id)?.title, 'Tên mới');
  });

  test('publishing a draft whose spot was archived meanwhile is spot_archived', async () => {
    const w = world();
    await saveEventDraft(w.deps, ph1, rawEvent(ID, 'ph1', { spotId: 'hoguom' }));
    w.store.spots.set('hoguom', spot('hoguom', { status: 'archived' }));
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: ID }), rejects('spot_archived'));
  });

  test('an event without the field reads spotId null', async () => {
    const w = world();
    const id = await publishedEvent(w, {});
    assert.equal(w.store.events.get(id)?.spotId ?? null, null);
    assert.equal(eventRecord().spotId ?? null, null);
  });
});
