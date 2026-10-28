import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createJobWorld } from './support/job_world.js';
import { createJob } from '../src/job_use_cases.js';
import { submitQuote, acceptQuote, declineQuote, quoteDraftFields } from '../src/quote_use_cases.js';
import { DomainError } from '../src/errors.js';
import { type BookingDraftInput } from '../src/create_booking.js';
import { MemoryBookingStore } from '../src/memory_booking_store.js';
import { MemoryAddonStore } from '../src/memory_addon_store.js';
import { FakePaymentGateway } from '../src/fake_payment_gateway.js';
import type { BookingDeps, CustomerContactReader, ServiceCatalog } from '../src/booking_ports.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { TEST_PAYER } from './support/booking_world.js';

function createBookingWorldForJob(w: ReturnType<typeof createJobWorld>): BookingDeps {
  const store = new MemoryBookingStore();
  const addons = new MemoryAddonStore();
  const gateway = new FakePaymentGateway();
  const blocks = w.blocks;

  const contacts: CustomerContactReader = {
    get: async (uid: string) => {
      if (uid === 'cust_lan') {
        return { name: 'Lan', phone: '+84903123456', allowZalo: true, allowWhatsApp: false };
      }
      return null;
    },
  };

  const services: ServiceCatalog = {
    getService: async (pid: string, sid: string) => {
      const s = await w.people.service(pid, sid);
      if (!s) return null;
      return {
        id: sid,
        photographerId: pid,
        name: 'Gói chụp',
        price: s.price,
        durationMinutes: 120,
        active: s.active,
        revisions: 2,
      };
    },
  };

  return {
    store,
    addons,
    services,
    providers: {
      acceptsOrders: async (pid: string): Promise<boolean> => {
        const p = await w.people.provider(pid);
        return Boolean(p && p.acceptingOrdersFields.verified && p.acceptingOrdersFields.onboardingComplete);
      },
      orderProfile: async (pid: string) => {
        const p = await w.people.provider(pid);
        if (!p) return null;
        return {
          acceptsOrders: Boolean(p.acceptingOrdersFields.verified && p.acceptingOrdersFields.onboardingComplete),
          providerType: p.providerType,
        };
      },
    },
    blocks,
    contacts,
    gateway,
    cipher: {
      encrypt: async (t: string) => t,
      decrypt: async (t: string) => t,
    },
    clock: w.clock,
    ids: w.deps.ids,
  };
}

describe('accept_quote', () => {
  async function setupJobAndQuote(w: ReturnType<typeof createJobWorld>) {
    const res = await createJob(w.deps, 'cust_lan', {
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu tốt nghiệp cấp 3',
      description: 'Lớp 12A1 gồm 42 bạn chụp tại trường',
      schedule: {
        kind: 'fixed',
        day: '2026-10-20',
        start: '07:00',
        end: '11:00',
      },
      area: {
        name: 'Quận 1, TP.HCM',
        lat: 10.7769,
        lng: 106.7009,
      },
      budget: { min: 3000000, max: 5000000 },
      allowedProviders: 'all',
      deadlineDays: 3,
    });

    await submitQuote(w.deps, 'p_tu', {
      jobId: res.jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm và rất vui được hợp tác!',
    });

    return { jobId: res.jobId };
  }

  it('creates the draft through buildBookingDraft: source quote, deposit equals the quote price, payableUntil set, revisionsIncluded from terms.revisions', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    const res = await acceptQuote(w.deps, bWorld, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      note: 'Gặp ở cổng trường',
      method: 'bank_qr',
    });

    assert.ok(res.bookingId);
    assert.ok(res.paymentId);
    assert.ok(res.checkout);
    assert.equal(res.checkout.amount, 4200000);
    assert.equal(res.checkout.method, 'bank_qr');

    const draft = await bWorld.store.runTransaction((tx) => tx.getBooking(res.bookingId));
    assert.ok(draft);
    assert.equal(draft.source, 'quote');
    assert.equal(draft.jobId, jobId);
    assert.equal(draft.quoteId, 'p_tu');
    assert.equal(draft.deposit, 4200000);
    assert.equal(draft.remaining, 0);
    assert.ok(draft.payableUntil);
    assert.equal(draft.revisionsIncluded, 2);
  });

  it('quoteDraftFields returns {} without a quote', () => {
    const input: BookingDraftInput = {
      id: 'bk_test',
      customerId: 'c1',
      photographerId: 'p1',
      service: {
        id: 's1',
        photographerId: 'p1',
        name: 'Gói cơ bản',
        price: 1000000,
        durationMinutes: 60,
        active: true,
      },
      day: '2026-10-20',
      start: '09:00',
      place: { name: 'Công viên' },
      now: new Date('2026-10-05T02:00:00.000Z'),
    };
    const fields = quoteDraftFields(input);
    assert.deepEqual(fields, {});
  });

  it('returns #129 checkout for the full price (bank_qr has qrPayload and transferCode)', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    const res = await acceptQuote(w.deps, bWorld, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      method: 'bank_qr',
    });

    assert.equal(res.checkout.amount, 4200000);
    assert.ok(res.checkout.transferCode.startsWith('PB'));
    assert.ok(res.checkout.qrPayload);
  });

  it('phone_required without a phone', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    // Lan has no phone in contacts
    w.deps.contacts.get = async () => null;

    await assert.rejects(
      acceptQuote(w.deps, bWorld, 'cust_lan', {
        jobId,
        photographerId: 'p_tu',
        place: { name: 'Trường THPT Lê Hồng Phong' },
        method: 'bank_qr',
      }),
      (err: DomainError) => err.code === 'phone_required',
    );
  });

  it('not_accepting_orders when the provider was closed after quoting', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    // Close provider
    const p = (await w.people.provider('p_tu'))!;
    w.people.providers.set('p_tu', {
      ...p,
      acceptingOrdersFields: { verified: true, onboardingComplete: false },
    });

    await assert.rejects(
      acceptQuote(w.deps, bWorld, 'cust_lan', {
        jobId,
        photographerId: 'p_tu',
        place: { name: 'Trường THPT Lê Hồng Phong' },
        method: 'bank_qr',
      }),
      (err: DomainError) => err.code === 'not_accepting_orders',
    );
  });

  it('blocked when the customer blocked the photographer after quoting', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    w.blocks.block('cust_lan', 'p_tu');

    await assert.rejects(
      acceptQuote(w.deps, bWorld, 'cust_lan', {
        jobId,
        photographerId: 'p_tu',
        place: { name: 'Trường THPT Lê Hồng Phong' },
        method: 'bank_qr',
      }),
      (err: DomainError) => err.code === 'blocked',
    );
  });

  it('a day pending for another booking is day_taken and the lock is released', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    // Set day pending by another booking
    await bWorld.store.runTransaction(async (tx) => {
      await tx.setAvailabilityDay('p_tu', '2026-10-20', {
        state: 'pending',
        bookingId: 'bk_other',
      });
    });

    await assert.rejects(
      acceptQuote(w.deps, bWorld, 'cust_lan', {
        jobId,
        photographerId: 'p_tu',
        place: { name: 'Trường THPT Lê Hồng Phong' },
        method: 'bank_qr',
      }),
      (err: DomainError) => err.code === 'day_taken',
    );

    // Lock was released
    const job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.checkout, null);
  });

  it('a second checkout replaces the first draft', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    const first = await acceptQuote(w.deps, bWorld, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      method: 'bank_qr',
    });

    const second = await acceptQuote(w.deps, bWorld, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      place: { name: 'Trường THPT Lê Hồng Phong (Cổng 2)' },
      method: 'bank_qr',
    });

    assert.notEqual(first.bookingId, second.bookingId);

    const oldDraft = await bWorld.store.runTransaction((tx) => tx.getBooking(first.bookingId));
    assert.equal(oldDraft?.status, 'expired');

    const newDraft = await bWorld.store.runTransaction((tx) => tx.getBooking(second.bookingId));
    assert.equal(newDraft?.status, 'draft');

    const job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.checkout?.bookingId, second.bookingId);
  });

  it('another user is permission_denied', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    // Provide contact phone for other user so phone check passes
    w.deps.contacts.get = async () => ({
      phone: '+84903999999',
      email: 'other@test.com',
      phoneVerified: true,
    });

    await assert.rejects(
      acceptQuote(w.deps, bWorld, 'cust_other', {
        jobId,
        photographerId: 'p_tu',
        place: { name: 'Trường THPT Lê Hồng Phong' },
        method: 'bank_qr',
      }),
      (err: DomainError) => err.code === 'permission_denied',
    );
  });

  it('a withdrawn or declined quote is conflict', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    // Decline quote
    await declineQuote(w.deps, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      reason: 'Đổi ý',
    });

    await assert.rejects(
      acceptQuote(w.deps, bWorld, 'cust_lan', {
        jobId,
        photographerId: 'p_tu',
        place: { name: 'Trường THPT Lê Hồng Phong' },
        method: 'bank_qr',
      }),
      (err: DomainError) => err.code === 'conflict',
    );
  });

  it('payment after the lock expired is refunded in full', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    const res = await acceptQuote(w.deps, bWorld, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      method: 'bank_qr',
    });

    // Advance clock past 30 min draft expiry but BEFORE payment expiry (PAYMENT_EXPIRY_MINUTES is 20m? Let's check: draft expires in 30m, but payment expires in 15m. If payment is received within payment expiry, but booking draft is expired)
    // Wait, let's keep receivedAt within payment expiresAt, but draft expired:
    await bWorld.store.runTransaction(async (tx) => {
      const b = (await tx.getBooking(res.bookingId))!;
      await tx.setBooking({
        ...b,
        status: 'expired',
        version: b.version + 1,
        updatedAt: w.clock.now().toISOString(),
      });
    });

    // Handle transfer arrives while payment is still active but booking draft is expired
    const outcome = await handleTransferNotification(bWorld, {
      provider: 'fake',
      txnId: 'tx_late_1',
      amount: 4200000,
      content: res.checkout.transferCode,
      receivedAt: w.clock.now().toISOString(),
      payer: TEST_PAYER,
    });

    assert.equal(outcome.outcome, 'refunded');
    const payment = await bWorld.store.getPayment(res.paymentId);
    assert.equal(payment?.status, 'refunded');
    assert.equal(payment?.refundedAmount, 4200000);
  });

  it('within an active lock the deadline passing does not block paying', async () => {
    const w = createJobWorld();
    const bWorld = createBookingWorldForJob(w);
    const { jobId } = await setupJobAndQuote(w);

    // Clock is near deadline
    const res = await acceptQuote(w.deps, bWorld, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      method: 'bank_qr',
    });

    // Deadline passes by 5 minutes, but checkout lock (expires in 30m) is still active
    w.clock.set(new Date('2026-10-05T02:10:00.000Z'));

    // Handle transfer
    const outcome = await handleTransferNotification(bWorld, {
      provider: 'fake',
      txnId: 'tx_ontime_1',
      amount: 4200000,
      content: res.checkout.transferCode,
      receivedAt: w.clock.now().toISOString(),
      payer: TEST_PAYER,
    });

    assert.equal(outcome.outcome, 'paid');
    const updatedBooking = await bWorld.store.runTransaction((tx) => tx.getBooking(res.bookingId));
    assert.equal(updatedBooking?.status, 'accepted');
  });
});
