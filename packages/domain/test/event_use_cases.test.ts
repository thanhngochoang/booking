import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { cancelRegistration, registerEvent } from '../src/event_registration.js';
import {
  cancelEvent, publishEvent, respondToHostConsent, saveEventDraft, updateEvent,
} from '../src/event_use_cases.js';
import {
  admin, cu1, cu2, createEventWorld, ph1, ph2, phNew, publishedEvent, rawEvent, register, registrationDoc,
  sales1, sales2, END, START, must,
} from './support/event_world.js';

const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;

describe('who may create and save', () => {
  test('a customer cannot create', async () => {
    const w = createEventWorld();
    await assert.rejects(saveEventDraft(w.deps, cu1, rawEvent('ev1', 'cu1')), code('permission_denied'));
  });

  test('a photographer without onboarding cannot create', async () => {
    const w = createEventWorld();
    await assert.rejects(saveEventDraft(w.deps, phNew, rawEvent('ev1', 'ph_new')), code('permission_denied'));
  });

  test('a photographer hosts themself', async () => {
    const w = createEventWorld();
    const { eventId } = await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    const ev = w.store.events.get(eventId);
    assert.equal(ev?.status, 'draft');
    assert.deepEqual([ev?.host.type, ev?.host.id, ev?.createdBy, ev?.createdByRole], ['photographer', 'ph1', 'ph1', 'photographer']);
    assert.equal(ev?.hostConsent, 'not_required');
    await assert.rejects(
      saveEventDraft(w.deps, ph1, rawEvent('ev2', 'ph1', { hostPhotographerId: 'ph2' })),
      code('permission_denied'),
    );
  });

  test('staff create platform events', async () => {
    const w = createEventWorld();
    const { eventId } = await saveEventDraft(w.deps, sales1, rawEvent('ev1', 'sales1'));
    const ev = w.store.events.get(eventId);
    assert.deepEqual([ev?.host.type, ev?.host.id, ev?.createdByRole, ev?.hostConsent], ['platform', null, 'sales', 'not_required']);
  });

  test('only managers save a draft', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    await assert.rejects(saveEventDraft(w.deps, ph2, { eventId: 'ev1', title: 'Hijack' }), code('permission_denied'));
    await assert.rejects(saveEventDraft(w.deps, cu1, { eventId: 'ev1', title: 'Hijack' }), code('permission_denied'));
    await saveEventDraft(w.deps, ph1, { eventId: 'ev1', title: 'Đổi tên' });
    await saveEventDraft(w.deps, admin, { eventId: 'ev1', description: 'staff edit' });
    assert.equal(w.store.events.get('ev1')?.title, 'Đổi tên');
    assert.equal(w.store.events.get('ev1')?.description, 'staff edit');
  });

  test('a draft needs a cover under the creator\'s own upload folder', async () => {
    const w = createEventWorld();
    await assert.rejects(
      saveEventDraft(w.deps, ph1, rawEvent('ev1', 'ph1', {
        coverPath: 'eventCovers/ph2/ev1/c.jpg', coverUrl: 'https://storage.test/eventCovers/ph2/ev1/c.jpg',
      })),
      code('invalid_argument'),
    );
  });

  test('saving a published event as a draft is a conflict', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await assert.rejects(saveEventDraft(w.deps, ph1, { eventId: 'ev1', title: 'x' }), code('conflict'));
  });
});

describe('hashtag', () => {
  test('first save reserves a unique hashtag', async () => {
    const w = createEventWorld();
    const r = await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    assert.equal(r.hashtag, 'PhotoWalkPhoCo1004');
    assert.equal(w.store.hashtags.get('photowalkphoco1004'), 'ev1');
    assert.equal(w.store.events.get('ev1')?.hashtagKey, 'photowalkphoco1004');
  });

  test('a taken hashtag gets a number suffix', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    const second = await saveEventDraft(w.deps, ph1, rawEvent('ev2'));
    const third = await saveEventDraft(w.deps, ph1, rawEvent('ev3'));
    assert.equal(second.hashtag, 'PhotoWalkPhoCo10042');
    assert.equal(third.hashtag, 'PhotoWalkPhoCo10043');
  });

  test('re-saving a draft keeps its hashtag', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    const again = await saveEventDraft(w.deps, ph1, { eventId: 'ev1', title: 'Tên khác hẳn' });
    assert.equal(again.hashtag, 'PhotoWalkPhoCo1004');
  });

  test('editing the hashtag moves the guard', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    const r = await saveEventDraft(w.deps, ph1, { eventId: 'ev1', hashtag: 'HanoiWalk' });
    assert.equal(r.hashtag, 'HanoiWalk');
    assert.equal(w.store.hashtags.has('photowalkphoco1004'), false);
    assert.equal(w.store.hashtags.get('hanoiwalk'), 'ev1');
    await saveEventDraft(w.deps, ph2, rawEvent('ev2', 'ph2'));
    await assert.rejects(saveEventDraft(w.deps, ph2, { eventId: 'ev2', hashtag: 'HANOIWALK' }), code('conflict'));
    await assert.rejects(saveEventDraft(w.deps, ph2, { eventId: 'ev2', hashtag: 'co dau' }), code('invalid_argument'));
  });

  test('the hashtag is locked after the first registration', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await updateEvent(w.deps, ph1, { eventId: 'ev1', hashtag: 'BeforeSales' }); // still free
    await register(w, cu1, 'ev1');
    assert.equal(w.store.events.get('ev1')?.hashtagLocked, true);
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: 'ev1', hashtag: 'TooLate' }), code('conflict'));
    // locked even when every ticket has been cancelled again
    const reg = w.store.registrationsOf('ev1')[0];
    await cancelRegistration(w.deps, cu1, { eventId: 'ev1', registrationId: must(reg).id });
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: 'ev1', hashtag: 'TooLate' }), code('conflict'));
  });

  test('a post locks it too', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.store.seedEvent({ ...must(w.store.events.get('ev1')), postCount: 1 });
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: 'ev1', hashtag: 'TooLate' }), code('conflict'));
  });
});

describe('publish', () => {
  test('publish validates every field', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, { eventId: 'ev1', title: 'Chỉ có tên', type: 'workshop' });
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: 'ev1' }), code('invalid_argument'));
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: 'nope' }), code('not_found'));
    await assert.rejects(publishEvent(w.deps, ph2, { eventId: 'ev1' }), code('permission_denied'));
  });

  test('publish opens the event and marks the host\'s day booked', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const ev = w.store.events.get('ev1');
    assert.equal(ev?.status, 'open');
    assert.equal(ev?.publishedAt?.getTime(), w.clock.now().getTime());
    assert.equal(ev?.registrationDeadline?.toISOString(), '2026-10-03T14:00:00.000Z');
    assert.equal(ev?.chatId, 'event_ev1');
    assert.deepEqual(w.store.availabilityDays.get('ph1/2026-10-04'), { state: 'booked', eventId: 'ev1' });
  });

  test('publish over a booked or pending day is day_taken', async () => {
    for (const state of ['booked', 'pending'] as const) {
      const w = createEventWorld();
      w.store.seedAvailability('ph1', '2026-10-04', { state, bookingId: 'b1' });
      await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
      await assert.rejects(publishEvent(w.deps, ph1, { eventId: 'ev1' }), code('day_taken'));
      assert.equal(w.store.events.get('ev1')?.status, 'draft');
    }
  });

  test('publish replaces an off day', async () => {
    const w = createEventWorld();
    w.store.seedAvailability('ph1', '2026-10-04', { state: 'off' });
    await publishedEvent(w);
    assert.equal(w.store.availabilityDays.get('ph1/2026-10-04')?.state, 'booked');
  });

  test('platform publish touches no availability', async () => {
    const w = createEventWorld();
    await publishedEvent(w, {}, sales1);
    assert.equal(w.store.availabilityDays.size, 0);
    assert.equal(w.store.events.get('ev1')?.status, 'open');
  });

  test('publish creates the group chat with the moderators', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const own = w.store.chats.get('event_ev1');
    assert.equal(own?.kind, 'event_group');
    assert.deepEqual(own?.moderators, ['ph1']);
    assert.deepEqual(own?.members, ['ph1']);
    assert.equal(own?.memberCount, 1);
    await publishedEvent(w, {}, sales1, 'ev2');
    assert.deepEqual(w.store.chats.get('event_ev2')?.moderators, ['sales1']);
  });

  test('publish twice is a conflict', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: 'ev1' }), code('conflict'));
  });
});

describe('update', () => {
  test('update after registrations keeps dates and refuses lower capacity than sold', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1', 3);
    await updateEvent(w.deps, ph1, { eventId: 'ev1', description: 'Mô tả mới', startAt: START });
    assert.equal(w.store.events.get('ev1')?.description, 'Mô tả mới');
    await assert.rejects(
      updateEvent(w.deps, ph1, { eventId: 'ev1', startAt: '2026-10-05T02:00:00.000Z', endAt: '2026-10-05T05:00:00.000Z' }),
      code('conflict'),
    );
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: 'ev1', capacity: 2 }), code('conflict'));
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: 'ev1', price: 50_000 }), code('conflict'));
    await updateEvent(w.deps, ph1, { eventId: 'ev1', capacity: 3 });
    assert.equal(w.store.events.get('ev1')?.status, 'full');
    await updateEvent(w.deps, ph1, { eventId: 'ev1', capacity: 8 });
    assert.equal(w.store.events.get('ev1')?.status, 'open');
    assert.equal(w.store.events.get('ev1')?.startAt?.toISOString(), START);
  });

  test('update moves the day when nobody registered', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await updateEvent(w.deps, ph1, { eventId: 'ev1', startAt: '2026-10-05T02:00:00.000Z', endAt: '2026-10-05T05:00:00.000Z' });
    const ev = w.store.events.get('ev1');
    assert.equal(ev?.dayKey, '2026-10-05');
    assert.equal(ev?.registrationDeadline?.toISOString(), '2026-10-04T14:00:00.000Z');
    assert.equal(w.store.availabilityDays.has('ph1/2026-10-04'), false);
    assert.equal(w.store.availabilityDays.get('ph1/2026-10-05')?.eventId, 'ev1');
  });

  test('moving onto a taken day is day_taken', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.store.seedAvailability('ph1', '2026-10-05', { state: 'booked', bookingId: 'b1' });
    await assert.rejects(
      updateEvent(w.deps, ph1, { eventId: 'ev1', startAt: '2026-10-05T02:00:00.000Z', endAt: '2026-10-05T05:00:00.000Z' }),
      code('day_taken'),
    );
    assert.equal(w.store.availabilityDays.get('ph1/2026-10-04')?.eventId, 'ev1');
  });

  test('update needs a published event and a manager', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: 'ev1', description: 'x' }), code('conflict'));
    await publishEvent(w.deps, ph1, { eventId: 'ev1' });
    await assert.rejects(updateEvent(w.deps, ph2, { eventId: 'ev1', description: 'x' }), code('permission_denied'));
  });
});

describe('cancel', () => {
  test('cancel frees the day and cancels free tickets', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1', 2);
    await register(w, cu2, 'ev1', 1);
    const r = await cancelEvent(w.deps, ph1, { eventId: 'ev1' });
    assert.deepEqual(r.paidRegistrationIds, []);
    const ev = w.store.events.get('ev1');
    assert.equal(ev?.status, 'cancelled');
    assert.equal(ev?.registeredCount, 0);
    assert.ok(ev?.cancelledAt);
    assert.equal(w.store.availabilityDays.has('ph1/2026-10-04'), false);
    assert.deepEqual(w.store.registrationsOf('ev1').map((x) => x.status), ['cancelled', 'cancelled']);
  });

  test('cancel returns paid registration ids for refunds', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const ev = must(w.store.events.get('ev1'));
    w.store.seedEvent({ ...ev, price: 100_000, registeredCount: 2, heldCount: 1 });
    w.store.seedRegistration(registrationDoc({ id: 'p1', eventId: 'ev1', amount: 200_000, quantity: 2, ticketCode: 'VE-AAAA-1004', contactEligible: true, paymentId: 'pay1' }));
    w.store.seedRegistration(registrationDoc({ id: 'h1', eventId: 'ev1', userId: 'cu8', amount: 100_000, status: 'held', holdExpiresAt: new Date(w.clock.now().getTime() + 60_000), ticketCode: 'VE-BBBB-1004' }));
    const r = await cancelEvent(w.deps, admin, { eventId: 'ev1' });
    assert.deepEqual(r.paidRegistrationIds, ['p1']);
    assert.equal(w.store.registrations.get('ev1/p1')?.status, 'paid');
    assert.equal(w.store.registrations.get('ev1/h1')?.status, 'cancelled');
    const after = w.store.events.get('ev1');
    assert.equal(after?.heldCount, 0);
    assert.equal(after?.registeredCount, 2);
  });

  test('cancel after the end is not_eligible', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.clock.set(new Date(new Date(END).getTime() + 60_000));
    await assert.rejects(cancelEvent(w.deps, ph1, { eventId: 'ev1' }), code('not_eligible'));
  });

  test('cancelling twice is not_eligible; a draft cancels and frees its hashtag', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, ph1, rawEvent('ev1'));
    await cancelEvent(w.deps, ph1, { eventId: 'ev1' });
    assert.equal(w.store.hashtags.size, 0);
    await assert.rejects(cancelEvent(w.deps, ph1, { eventId: 'ev1' }), code('not_eligible'));
  });

  test('a sales user cannot cancel another sales user\'s event', async () => {
    const w = createEventWorld();
    await publishedEvent(w, {}, sales1);
    await assert.rejects(cancelEvent(w.deps, sales2, { eventId: 'ev1' }), code('permission_denied'));
    await assert.rejects(cancelEvent(w.deps, cu1, { eventId: 'ev1' }), code('permission_denied'));
    await cancelEvent(w.deps, admin, { eventId: 'ev1' });
    assert.equal(w.store.events.get('ev1')?.status, 'cancelled');
  });

  test('a cancelled event takes no registrations', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await cancelEvent(w.deps, ph1, { eventId: 'ev1' });
    await assert.rejects(registerEvent(w.deps, cu1, { eventId: 'ev1', quantity: 1, name: 'An' }), code('deadline_passed'));
  });
});

describe('O1: staff create an event for a photographer', () => {
  const forPh1 = (id = 'ev1') => rawEvent(id, 'sales1', { hostPhotographerId: 'ph1' });

  test('it is a draft with a pending consent that lasts 24 hours', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, forPh1());
    const ev = w.store.events.get('ev1');
    assert.deepEqual([ev?.host.type, ev?.host.id, ev?.createdBy, ev?.hostConsent], ['photographer', 'ph1', 'sales1', 'pending']);
    assert.equal(ev?.hostConsentExpiresAt?.getTime(), w.clock.now().getTime() + 24 * 3_600_000);
    assert.equal(ev?.status, 'draft');
  });

  test('the host must be an onboarded photographer', async () => {
    const w = createEventWorld();
    await assert.rejects(saveEventDraft(w.deps, sales1, rawEvent('ev1', 'sales1', { hostPhotographerId: 'ph_new' })), code('not_eligible'));
    await assert.rejects(saveEventDraft(w.deps, sales1, rawEvent('ev1', 'sales1', { hostPhotographerId: 'ghost' })), code('not_eligible'));
  });

  test('only an accepted event publishes, and it books the photographer\'s day', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, forPh1());
    await assert.rejects(publishEvent(w.deps, sales1, { eventId: 'ev1' }), code('not_eligible'));
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: 'ev1' }), code('not_eligible'));
    await respondToHostConsent(w.deps, ph1, { eventId: 'ev1', accept: true });
    assert.equal(w.store.events.get('ev1')?.hostConsent, 'accepted');
    await publishEvent(w.deps, sales1, { eventId: 'ev1' });
    assert.equal(w.store.events.get('ev1')?.status, 'open');
    assert.equal(w.store.availabilityDays.get('ph1/2026-10-04')?.eventId, 'ev1');
    assert.deepEqual(w.store.chats.get('event_ev1')?.moderators, ['ph1', 'sales1']);
  });

  test('only the invited photographer answers, once', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, forPh1());
    await assert.rejects(respondToHostConsent(w.deps, ph2, { eventId: 'ev1', accept: true }), code('permission_denied'));
    await assert.rejects(respondToHostConsent(w.deps, sales1, { eventId: 'ev1', accept: true }), code('permission_denied'));
    await assert.rejects(respondToHostConsent(w.deps, ph1, { eventId: 'ev1' }), code('invalid_argument'));
    await respondToHostConsent(w.deps, ph1, { eventId: 'ev1', accept: true });
    await assert.rejects(respondToHostConsent(w.deps, ph1, { eventId: 'ev1', accept: false }), code('conflict'));
  });

  test('declining cancels the draft and frees the hashtag', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, forPh1());
    await respondToHostConsent(w.deps, ph1, { eventId: 'ev1', accept: false });
    const ev = w.store.events.get('ev1');
    assert.deepEqual([ev?.hostConsent, ev?.status], ['declined', 'cancelled']);
    assert.equal(w.store.hashtags.size, 0);
    await assert.rejects(publishEvent(w.deps, sales1, { eventId: 'ev1' }), code('conflict'));
  });

  test('answering after 24 hours expires the draft', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, forPh1());
    w.clock.advance(24 * 3_600_000);
    await assert.rejects(respondToHostConsent(w.deps, ph1, { eventId: 'ev1', accept: true }), code('deadline_passed'));
    const ev = w.store.events.get('ev1');
    assert.deepEqual([ev?.hostConsent, ev?.status], ['expired', 'cancelled']);
    assert.equal(w.store.hashtags.size, 0);
  });

  test('the photographer may also edit the draft; staff stay managers', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, forPh1());
    await saveEventDraft(w.deps, ph1, { eventId: 'ev1', description: 'chủ sự kiện sửa' });
    await assert.rejects(saveEventDraft(w.deps, sales2, { eventId: 'ev1', description: 'x' }), code('permission_denied'));
    await assert.rejects(saveEventDraft(w.deps, sales1, { eventId: 'ev1', hostPhotographerId: 'ph2' }), code('invalid_argument'));
  });
});

describe('O2: FAQ on platform events', () => {
  const faq = [{ question: 'Có gửi xe không?', answer: 'Có, miễn phí.' }];

  test('staff set the FAQ on a platform event', async () => {
    const w = createEventWorld();
    await saveEventDraft(w.deps, sales1, rawEvent('ev1', 'sales1', { faq }));
    assert.deepEqual(w.store.events.get('ev1')?.faq, faq);
    await publishEvent(w.deps, sales1, { eventId: 'ev1' });
    await updateEvent(w.deps, admin, { eventId: 'ev1', faq: [] });
    assert.deepEqual(w.store.events.get('ev1')?.faq, []);
  });

  test('a photographer cannot set it, and a photographer-hosted event takes none', async () => {
    const w = createEventWorld();
    await assert.rejects(saveEventDraft(w.deps, ph1, rawEvent('ev1', 'ph1', { faq })), code('permission_denied'));
    await assert.rejects(
      saveEventDraft(w.deps, sales1, rawEvent('ev2', 'sales1', { faq, hostPhotographerId: 'ph1' })),
      code('invalid_argument'),
    );
  });
});
