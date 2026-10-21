import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryChatStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryStudioStore,
  MemoryUserDirectory,
  type BadgeDeps,
  type ChatDeps,
  type NotifyDeps,
  type StudioBookingDeps,
  type StudioDeps,
} from '@photobooking/domain';
import { handleStudioDayWrite } from '../../src/triggers/availability_write.js';
import { handleBookingWrite, studioDaysOf } from '../../src/triggers/booking_write.js';
import { studiosToRecompute } from '../../src/triggers/photographer_write.js';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { bookingToFirestore } from '../../src/infra/booking_firestore.js';
import { captureLogs, paymentWorld } from './support/payment_world.js';
import { NOW, STUDIO, studioBooking } from './support/studio_fixtures.js';

function notifyDeps(now = NOW): { deps: NotifyDeps; store: MemoryNotificationStore } {
  const store = new MemoryNotificationStore();
  return { store, deps: { store, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => now } } };
}

describe('availability trigger → studio day (Decision 26)', () => {
  const profiles: Record<string, { studioId: string | null; providerType: 'individual' | 'studio' }> = {
    m1: { studioId: STUDIO, providerType: 'individual' },
    solo: { studioId: null, providerType: 'individual' },
    [STUDIO]: { studioId: null, providerType: 'studio' },
  };
  function deps(calls: string[]) {
    return {
      now: () => NOW,
      profile: async (uid: string) => profiles[uid] ?? null,
      recompute: async (studioId: string, day: string) => {
        calls.push(`${studioId}/${day}`);
      },
    };
  }

  it("a member's personal booking day triggers the studio recompute", async () => {
    const calls: string[] = [];
    const out = await handleStudioDayWrite('m1', '2026-10-14', undefined, { state: 'pending', bookingId: 'own' }, deps(calls));
    assert.equal(out, STUDIO);
    assert.deepEqual(calls, [`${STUDIO}/2026-10-14`]);
  });

  it("a studio's own off day recomputes it; its full mark, a past day and a non-member do not", async () => {
    const calls: string[] = [];
    await handleStudioDayWrite(STUDIO, '2026-10-14', { state: 'off' }, undefined, deps(calls));
    await handleStudioDayWrite(STUDIO, '2026-10-15', undefined, { state: 'full' }, deps(calls));
    await handleStudioDayWrite(STUDIO, '2026-10-16', { state: 'full' }, undefined, deps(calls));
    await handleStudioDayWrite('m1', '2026-10-01', undefined, { state: 'off' }, deps(calls));
    await handleStudioDayWrite('solo', '2026-10-14', undefined, { state: 'off' }, deps(calls));
    await handleStudioDayWrite('ghost', '2026-10-14', undefined, { state: 'off' }, deps(calls));
    assert.deepEqual(calls, [`${STUDIO}/2026-10-14`]);
  });
});

describe('onPhotographerWrite → studios to recompute', () => {
  const member = { onboardingComplete: true, verified: true, studioId: STUDIO };

  it('join, leave and a change of the gate move the studio; other writes do not', () => {
    assert.deepEqual(studiosToRecompute({ uid: 'm1', before: { ...member, studioId: null }, after: member }), [STUDIO]);
    assert.deepEqual(studiosToRecompute({ uid: 'm1', before: member, after: { ...member, studioId: null } }), [STUDIO]);
    assert.deepEqual(
      studiosToRecompute({ uid: 'm1', before: member, after: { ...member, studioId: 'studio_2' } }).sort(),
      [STUDIO, 'studio_2'].sort(),
    );
    assert.deepEqual(studiosToRecompute({ uid: 'm1', before: member, after: { ...member, verified: false } }), [STUDIO]);
    assert.deepEqual(studiosToRecompute({ uid: 'm1', before: member, after: { ...member, bio: 'x' } }), []);
  });

  it('a studio that becomes individual loses its marks', () => {
    assert.deepEqual(
      studiosToRecompute({ uid: STUDIO, before: { providerType: 'studio' }, after: { providerType: 'individual' } }),
      [STUDIO],
    );
  });
});

describe('onBookingWrite studio wiring', () => {
  const chatDeps: ChatDeps = {
    chats: new MemoryChatStore(),
    photographers: { acceptsInquiries: async () => true },
    blocks: { isBlockedEitherWay: async () => false },
    clock: { now: () => NOW },
    ids: { newId: () => 'id_1' },
  };

  it('an assignment sends booking_assigned and recomputes the studio day', async () => {
    const n = notifyDeps();
    const recomputed: string[] = [];
    const before = studioBooking();
    const after = studioBooking({ assigneeId: 'm1', assigneeKind: 'member', assignStatus: 'assigned', assignedAt: NOW.toISOString(), version: 2 });
    await handleBookingWrite(
      { id: before.id, before: bookingToFirestore(before), after: bookingToFirestore(after) },
      chatDeps,
      async () => undefined,
      {
        notify: n.deps,
        badges: {} as BadgeDeps,
        studioDays: async (studioId, day) => {
          recomputed.push(`${studioId}/${day}`);
        },
      },
    );
    assert.deepEqual(n.store.rowsOf('m1').map((r) => r.type), ['booking_assigned']);
    assert.deepEqual(recomputed, [`${STUDIO}/2026-10-14`]);
  });

  it('studioDaysOf: only studio bookings, and only when status, day or assignee changed', () => {
    const b = studioBooking();
    assert.deepEqual(studioDaysOf(null, b), [{ studioId: STUDIO, day: '2026-10-14' }]);
    assert.deepEqual(studioDaysOf(b, { ...b, chatId: 'c1' }), []);
    assert.deepEqual(studioDaysOf(b, { ...b, status: 'cancelled' }), [{ studioId: STUDIO, day: '2026-10-14' }]);
    assert.deepEqual(studioDaysOf(b, null), [{ studioId: STUDIO, day: '2026-10-14' }]);
    const solo = studioBooking({ isStudio: undefined, photographerId: 'p1' });
    assert.deepEqual(studioDaysOf(null, solo), []);
  });
});

describe('bookingClock studio steps', () => {
  function studioWorld() {
    const w = paymentWorld(NOW);
    const bookings: StudioBookingDeps = {
      ...w.deps,
      store: w.store,
      roster: { relationOf: async () => null, person: async () => null },
    };
    const studios = new MemoryStudioStore();
    const members: StudioDeps = { studios, clock: { now: () => NOW }, ids: { newId: () => 'x' } };
    return { w, bookings, studios, members };
  }

  it('bookingClock runs the studio steps and survives their failure', async (t) => {
    const { w, bookings, studios, members } = studioWorld();
    // Past its deadline, still ahead: marked overdue. An invite past expiresAt: expired.
    w.store.bookings.set('due', studioBooking({ id: 'due', assignDeadline: new Date(NOW.getTime() - 60_000).toISOString() }));
    studios.relations.set('r1', {
      id: 'r1', studioId: STUDIO, memberId: 'm1', status: 'invited', initiatedBy: 'studio',
      createdAt: new Date(NOW.getTime() - 8 * 86_400_000).toISOString(), expiresAt: new Date(NOW.getTime() - 1000).toISOString(),
      respondedAt: null, joinedAt: null, endedAt: null, endedBy: null, expiringNotifiedAt: null,
      studioName: 'Cúc', studioAvatarUrl: null, memberName: 'An', memberAvatarUrl: null, version: 1,
    });
    const n = notifyDeps();
    await handleBookingClock(w.deps, undefined, { studio: { bookings, members, notify: n.deps } });
    assert.equal(w.store.bookings.get('due')?.assignOverdue, true);
    assert.equal(studios.relations.get('r1')?.status, 'expired');
    assert.deepEqual(n.store.rowsOf(STUDIO).map((r) => r.type), ['assign_overdue']);

    // The booking step throws: logged, the membership step still runs, the clock resolves.
    const broken: StudioBookingDeps = {
      ...bookings,
      store: Object.assign(Object.create(w.store) as typeof w.store, {
        findUnassignedStudioBookingsDue: async () => {
          throw new Error('index missing');
        },
      }),
    };
    const r1 = studios.relations.get('r1');
    assert.ok(r1);
    studios.relations.set('r2', { ...r1, id: 'r2', status: 'requested', version: 1 });
    const lines = await captureLogs(t, () =>
      handleBookingClock(w.deps, undefined, { studio: { bookings: broken, members, notify: n.deps } }),
    );
    assert.ok(lines.some((l) => l.includes('bookingClock studioBookingSweeps failed')));
    assert.equal(studios.relations.get('r2')?.status, 'expired');
  });

  it('failed sweep notices are logged as errors', async (t) => {
    const { w, bookings, members } = studioWorld();
    w.store.bookings.set('due', studioBooking({ id: 'due', assignDeadline: new Date(NOW.getTime() - 60_000).toISOString() }));
    const broken = { ...notifyDeps().deps, store: { runTransaction: async () => { throw new Error('down'); } } } as unknown as NotifyDeps;
    const lines = await captureLogs(t, () => handleBookingClock(w.deps, undefined, { studio: { bookings, members, notify: broken } }));
    assert.ok(lines.some((l) => l.includes('studioBookingSweeps notices failed') && l.includes('"notifyFailed":1')));
    // Not marked: the next tick sends the notice again.
    assert.equal(w.store.bookings.get('due')?.assignOverdue, false);
  });
});
