import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  confirmFakePayment,
  checkSubjectPayments,
  readPaymentInstructions,
  runPaymentSweeps,
  settleTransfer,
  transferRecordOf,
  type Payment,
  type Refund,
  type SubjectSettler,
  type TransferNotification,
  type TransferOutcome,
  type TransferRecord,
  type SettlementDeps,
} from '../src/index.js';
import { MemoryPaymentLookup, type PaymentSource } from '../src/memory_payment_lookup.js';
import { FakePaymentGateway } from '../src/fake_payment_gateway.js';
import { ControllableClock, createBookingWorld, newDraft, transferOf } from './support/booking_world.js';
import { createPayment } from '../src/create_payment.js';
import { DomainError } from '../src/errors.js';

class RecordingSettler implements SubjectSettler {
  readonly settleCalls: { paymentId: string; transfer: TransferNotification }[] = [];
  readonly expireCalls: { paymentId: string; now: Date }[] = [];
  readonly refundCalls: unknown[] = [];
  expireThrows = false;
  settleOutcome: Exclude<TransferOutcome, 'needs_review'> = 'paid';

  constructor(
    private readonly source: PaymentSource,
    public statusString = 'custom_active',
  ) {}

  async settle(paymentId: string, transfer: TransferNotification): Promise<Exclude<TransferOutcome, 'needs_review'>> {
    this.settleCalls.push({ paymentId, transfer });
    return this.settleOutcome;
  }

  async expire(paymentId: string, now: Date): Promise<'expired' | 'unchanged'> {
    this.expireCalls.push({ paymentId, now });
    if (this.expireThrows) throw new Error('simulated_expire_throw');
    const p = this.source.payments.get(paymentId);
    if (p && p.status === 'created') {
      (this.source.payments as Map<string, Payment>).set(paymentId, {
        ...p,
        status: 'expired',
      });
      return 'expired';
    }
    return 'unchanged';
  }

  async dispatchRefund(refund: Refund, _payment: Payment): Promise<Refund> {
    this.refundCalls.push(refund);
    void _payment;
    return refund;
  }

  async statusOf(_payment: Payment): Promise<string> {
    void _payment;
    return this.statusString;
  }
}

describe('Task 2: Domain settlement dispatch', () => {
  it('settleTransfer hands a booking transfer to subjects.booking with the same outcome as handleTransferNotification', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    const n = transferOf(world, { content: res.checkout.transferCode, amount: 1_000_000 });
    const result = await settleTransfer(world.settlement, n);

    assert.equal(result.outcome, 'paid');
    assert.equal(result.paymentId, res.paymentId);

    const booking = await world.store.getBooking(draft.id);
    assert.equal(booking?.status, 'requested');
  });

  it('settleTransfer hands another subject\'s transfer to its settler', async () => {
    const paymentsMap = new Map<string, Payment>();
    const transferRecordsMap = new Map<string, TransferRecord>();
    const customSource: PaymentSource = {
      payments: paymentsMap,
      transferRecords: transferRecordsMap,
    };
    const settler = new RecordingSettler(customSource, 'tkt_confirmed');
    const lookup = new MemoryPaymentLookup([customSource]);
    const gateway = new FakePaymentGateway();
    const clock = new ControllableClock();

    const customDeps: SettlementDeps = {
      payments: lookup,
      gateway,
      clock,
      subjects: {
        event_registration: settler,
      },
    };

    const p: Payment = {
      id: 'p_event_1',
      subjectType: 'event_registration',
      subjectId: 'reg_001',
      payerId: 'u1',
      payeeId: 'host1',
      provider: 'fake',
      amount: 200_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k_evt',
      transferCode: 'PB 234567',
      createdAt: clock.now().toISOString(),
      updatedAt: clock.now().toISOString(),
    };
    paymentsMap.set(p.id, p);

    const n: TransferNotification = {
      provider: 'fake',
      txnId: 'txn_tkt_1',
      amount: 200_000,
      content: 'PB 234567',
      receivedAt: clock.now().toISOString(),
    };

    const result = await settleTransfer(customDeps, n);
    assert.equal(result.outcome, 'paid');
    assert.equal(result.paymentId, 'p_event_1');
    assert.equal(settler.settleCalls.length, 1);
    assert.equal(settler.settleCalls[0]?.paymentId, 'p_event_1');
  });

  it('a payment whose subject has no settler is needs_review and only the transfer record is written', async () => {
    const paymentsMap = new Map<string, Payment>();
    const transferRecordsMap = new Map<string, TransferRecord>();
    const customSource: PaymentSource = { payments: paymentsMap, transferRecords: transferRecordsMap };
    const lookup = new MemoryPaymentLookup([customSource]);
    const gateway = new FakePaymentGateway();
    const clock = new ControllableClock();

    const depsWithoutSettler: SettlementDeps = {
      payments: lookup,
      gateway,
      clock,
      subjects: {}, // No settler for event_registration
    };

    const p: Payment = {
      id: 'p_nosettler',
      subjectType: 'event_registration',
      subjectId: 'reg_99',
      payerId: 'u1',
      payeeId: 'host1',
      provider: 'fake',
      amount: 200_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k_no',
      transferCode: 'PB NOSETTLER',
      createdAt: clock.now().toISOString(),
      updatedAt: clock.now().toISOString(),
    };
    paymentsMap.set(p.id, p);

    const n: TransferNotification = {
      provider: 'fake',
      txnId: 'txn_nosettler',
      amount: 200_000,
      content: 'PB NOSETTLER',
      receivedAt: clock.now().toISOString(),
    };

    const result = await settleTransfer(depsWithoutSettler, n);
    assert.equal(result.outcome, 'needs_review');
    assert.equal(result.paymentId, undefined);

    const rec = await lookup.getTransferRecord('fake_txn_nosettler');
    assert.ok(rec);
    assert.equal(rec.outcome, 'needs_review');
  });

  it('unmatched content is needs_review once; the second delivery is duplicate', async () => {
    const world = createBookingWorld();
    const n: TransferNotification = {
      provider: 'fake',
      txnId: 'txn_unmatched',
      amount: 500_000,
      content: 'CHUYEN TIEN KHONG TIM THAY',
      receivedAt: world.clock.now().toISOString(),
    };

    const first = await settleTransfer(world.settlement, n);
    assert.equal(first.outcome, 'needs_review');

    const second = await settleTransfer(world.settlement, n);
    assert.equal(second.outcome, 'duplicate');
  });

  it('a repeated transfer is duplicate without calling the settler', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    const n = transferOf(world, { content: res.checkout.transferCode, amount: 1_000_000 });
    const first = await settleTransfer(world.settlement, n);
    assert.equal(first.outcome, 'paid');

    const second = await settleTransfer(world.settlement, n);
    assert.equal(second.outcome, 'duplicate');
    assert.equal(second.paymentId, res.paymentId);
  });

  it('the open payment wins over an older closed payment with the same code', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const code = 'PB 345678';

    world.store.payments.set('p_closed', {
      id: 'p_closed',
      subjectType: 'booking',
      subjectId: 'b_old',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 1_000_000,
      status: 'expired',
      escrowStatus: 'refunded',
      idempotencyKey: 'k_old',
      transferCode: code,
      createdAt: '2026-10-10T09:00:00.000Z',
      updatedAt: '2026-10-10T09:30:00.000Z',
    });

    world.store.payments.set('p_open', {
      id: 'p_open',
      subjectType: 'booking',
      subjectId: draft.id,
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 1_000_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k_open',
      transferCode: code,
      expiresAt: '2026-10-10T10:15:00.000Z',
      createdAt: '2026-10-10T09:10:00.000Z',
      updatedAt: '2026-10-10T09:10:00.000Z',
    });

    const n = transferOf(world, { content: code, amount: 1_000_000, receivedAt: '2026-10-10T10:05:00.000Z' });
    const res = await settleTransfer(world.settlement, n);
    assert.equal(res.outcome, 'paid');
    assert.equal(res.paymentId, 'p_open');
  });

  it('a payment created after the transfer is never matched', async () => {
    const world = createBookingWorld();
    const code = 'PB FUTURE';

    world.store.payments.set('p_future', {
      id: 'p_future',
      subjectType: 'booking',
      subjectId: 'b_future',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 1_000_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k_fut',
      transferCode: code,
      createdAt: '2026-10-10T12:00:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    });

    // Transfer received before createdAt
    const n: TransferNotification = {
      provider: 'fake',
      txnId: 'txn_before',
      amount: 1_000_000,
      content: code,
      receivedAt: '2026-10-10T11:00:00.000Z',
    };

    const res = await settleTransfer(world.settlement, n);
    assert.equal(res.outcome, 'needs_review');
  });

  it('runPaymentSweeps reconciles and expires every subject through its settler and counts them', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    // 1. Reconcile: advance 4 minutes, push a transfer to gateway
    world.clock.advanceMinutes(4);
    world.gateway.pushTransfer(
      res.paymentId,
      transferOf(world, { content: res.checkout.transferCode, amount: 1_000_000 }),
    );

    const sweep1 = await runPaymentSweeps(world.settlement);
    assert.equal(sweep1.reconciled, 1);
    assert.equal(sweep1.expired, 0);

    // 2. Expire: create another payment, don't pay, advance past 15 min
    const draft2 = await newDraft(world, { day: '2026-10-16' });
    await createPayment(world.deps, { bookingId: draft2.id, customerId: 'c1', method: 'bank_qr' });
    world.clock.advanceMinutes(20);

    const sweep2 = await runPaymentSweeps(world.settlement);
    assert.equal(sweep2.expired, 1);
    assert.equal(sweep2.refunded, 0);
  });

  it('runPaymentSweeps skips a subject without a settler and still finishes the batch', async () => {
    const paymentsMap = new Map<string, Payment>();
    const transferRecordsMap = new Map<string, TransferRecord>();
    const source: PaymentSource = { payments: paymentsMap, transferRecords: transferRecordsMap };
    const settler = new RecordingSettler(source);
    const lookup = new MemoryPaymentLookup([source]);
    const gateway = new FakePaymentGateway();
    const clock = new ControllableClock();

    const deps: SettlementDeps = {
      payments: lookup,
      gateway,
      clock,
      subjects: {
        booking: settler,
        // event_registration has no settler
      },
    };

    // overdue booking payment
    paymentsMap.set('p_bk', {
      id: 'p_bk',
      subjectType: 'booking',
      subjectId: 'b_1',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 100_000,
      method: 'bank_qr',
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k1',
      transferCode: 'PB BK111',
      expiresAt: '2026-10-10T09:00:00.000Z',
      createdAt: '2026-10-10T08:45:00.000Z',
      updatedAt: '2026-10-10T08:45:00.000Z',
    });

    // overdue event_registration payment (no settler)
    paymentsMap.set('p_ev', {
      id: 'p_ev',
      subjectType: 'event_registration',
      subjectId: 'reg_1',
      payerId: 'c1',
      payeeId: 'host1',
      provider: 'fake',
      amount: 100_000,
      method: 'bank_qr',
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k2',
      transferCode: 'PB EV222',
      expiresAt: '2026-10-10T09:00:00.000Z',
      createdAt: '2026-10-10T08:45:00.000Z',
      updatedAt: '2026-10-10T08:45:00.000Z',
    });

    clock.advanceMinutes(30);
    const sweep = await runPaymentSweeps(deps);
    assert.equal(sweep.expired, 1); // p_bk expired, p_ev skipped
    assert.equal(settler.expireCalls.length, 1);
    assert.equal(settler.expireCalls[0]?.paymentId, 'p_bk');
  });

  it('a settler.expire that throws is counted as expireFailed and the next payment still expires', async () => {
    const paymentsMap = new Map<string, Payment>();
    const transferRecordsMap = new Map<string, TransferRecord>();
    const source: PaymentSource = { payments: paymentsMap, transferRecords: transferRecordsMap };
    const settler = new RecordingSettler(source);
    const lookup = new MemoryPaymentLookup([source]);
    const gateway = new FakePaymentGateway();
    const clock = new ControllableClock();

    const deps: SettlementDeps = {
      payments: lookup,
      gateway,
      clock,
      subjects: {
        booking: settler,
      },
    };

    paymentsMap.set('p1', {
      id: 'p1',
      subjectType: 'booking',
      subjectId: 'b_1',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 100_000,
      method: 'bank_qr',
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k1',
      transferCode: 'PB 456789',
      expiresAt: '2026-10-10T09:00:00.000Z',
      createdAt: '2026-10-10T08:45:00.000Z',
      updatedAt: '2026-10-10T08:45:00.000Z',
    });

    paymentsMap.set('p2', {
      id: 'p2',
      subjectType: 'booking',
      subjectId: 'b_2',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 100_000,
      method: 'bank_qr',
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k2',
      transferCode: 'PB 56789A',
      expiresAt: '2026-10-10T09:00:00.000Z',
      createdAt: '2026-10-10T08:45:00.000Z',
      updatedAt: '2026-10-10T08:45:00.000Z',
    });

    settler.expire = async (paymentId, _now) => {
      void _now;
      if (paymentId === 'p1') {
        throw new Error('simulated_failure');
      }
      const p = source.payments.get(paymentId);
      if (p && p.status === 'created') {
        (source.payments as Map<string, Payment>).set(paymentId, { ...p, status: 'expired' });
        return 'expired';
      }
      return 'unchanged';
    };

    const sweep = await runPaymentSweeps(deps);
    assert.equal(sweep.expireFailed, 1);
    assert.equal(sweep.expired, 1);
  });

  it('checkSubjectPayments settles a transfer found by queryTransfers and returns true; false when nothing arrived', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    const p = await world.store.getPayment(res.paymentId);
    assert.ok(p);

    // False initially
    const falseRes = await checkSubjectPayments(world.settlement, [p]);
    assert.equal(falseRes, false);

    // Push transfer to gateway
    assert.ok(p.transferCode);
    world.gateway.pushTransfer(p.id, transferOf(world, { content: p.transferCode, amount: p.amount }));
    const trueRes = await checkSubjectPayments(world.settlement, [p]);
    assert.equal(trueRes, true);
  });

  it('confirmFakePayment exact/under/over/wrong_content give paid/partial/paid_with_refund/needs_review through the settler', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const caller = { uid: 'c1' };

    // 1. exact → paid
    const resExact = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    const exactOutcome = await confirmFakePayment(world.settlement, caller, { paymentId: resExact.paymentId, kind: 'exact' });
    assert.equal(exactOutcome.outcome, 'paid');
    assert.equal(exactOutcome.paymentStatus, 'paid');
    assert.equal(exactOutcome.subjectStatus, 'requested');

    // 2. under → partial
    const draft2 = await newDraft(world, { day: '2026-10-16' });
    const resUnder = await createPayment(world.deps, { bookingId: draft2.id, customerId: 'c1', method: 'bank_qr' });
    const underOutcome = await confirmFakePayment(world.settlement, caller, { paymentId: resUnder.paymentId, kind: 'under' });
    assert.equal(underOutcome.outcome, 'partial');
    assert.equal(underOutcome.paymentStatus, 'created');
    assert.equal(underOutcome.subjectStatus, 'draft');

    // 3. over → paid_with_refund
    const draft3 = await newDraft(world, { day: '2026-10-17' });
    const resOver = await createPayment(world.deps, { bookingId: draft3.id, customerId: 'c1', method: 'bank_qr' });
    const overOutcome = await confirmFakePayment(world.settlement, caller, { paymentId: resOver.paymentId, kind: 'over' });
    assert.equal(overOutcome.outcome, 'paid_with_refund');
    assert.equal(overOutcome.paymentStatus, 'paid');
    assert.equal(overOutcome.subjectStatus, 'requested');

    // 4. wrong_content → needs_review
    const draft4 = await newDraft(world, { day: '2026-10-18' });
    const resWrong = await createPayment(world.deps, { bookingId: draft4.id, customerId: 'c1', method: 'bank_qr' });
    const wrongOutcome = await confirmFakePayment(world.settlement, caller, { paymentId: resWrong.paymentId, kind: 'wrong_content' });
    assert.equal(wrongOutcome.outcome, 'needs_review');
    assert.equal(wrongOutcome.paymentStatus, 'created');
  });

  it('confirmFakePayment: another payer is permission_denied; no settler is not_eligible; it returns statusOf', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    // Another payer
    await assert.rejects(
      confirmFakePayment(world.settlement, { uid: 'someone_else' }, { paymentId: res.paymentId }),
      (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
    );

    // No settler
    const emptySettlement: SettlementDeps = {
      ...world.settlement,
      subjects: {},
    };
    await assert.rejects(
      confirmFakePayment(emptySettlement, { uid: 'c1' }, { paymentId: res.paymentId }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );
  });

  it('readPaymentInstructions: the payer gets a created payment\'s instructions; null once paid; another user is permission_denied', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    // Payer reads instructions
    const inst = await readPaymentInstructions(world.settlement, { uid: 'c1' }, { paymentId: res.paymentId });
    assert.ok(inst);
    assert.equal(inst.paymentId, res.paymentId);
    assert.equal(inst.amount, 1_000_000);
    assert.equal(inst.method, 'bank_qr');

    // Another user
    await assert.rejects(
      readPaymentInstructions(world.settlement, { uid: 'c2' }, { paymentId: res.paymentId }),
      (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
    );

    // Once paid → null
    await confirmFakePayment(world.settlement, { uid: 'c1' }, { paymentId: res.paymentId });
    const paidInst = await readPaymentInstructions(world.settlement, { uid: 'c1' }, { paymentId: res.paymentId });
    assert.equal(paidInst, null);
  });

  it('BookingPaymentSettler.statusOf gives the booking status, and gone when the draft was deleted', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    const p = await world.store.getPayment(res.paymentId);
    assert.ok(p);

    const settler = world.settlement.subjects.booking;
    assert.ok(settler);
    assert.equal(await settler.statusOf(p), 'draft');

    await world.store.deleteBooking(draft.id);
    assert.equal(await settler.statusOf(p), 'gone');
  });

  it('MemoryPaymentLookup sees the payments of every source and stores an unmatched record once', async () => {
    const map1 = new Map<string, Payment>();
    const map2 = new Map<string, Payment>();
    const recs1 = new Map<string, TransferRecord>();
    const recs2 = new Map<string, TransferRecord>();

    const p1: Payment = {
      id: 'p_src1',
      subjectType: 'booking',
      subjectId: 'b_1',
      payerId: 'u1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 100_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k1',
      transferCode: 'PB SRC1',
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    };
    const p2: Payment = {
      id: 'p_src2',
      subjectType: 'event_registration',
      subjectId: 'r_1',
      payerId: 'u2',
      payeeId: 'host1',
      provider: 'fake',
      amount: 200_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'k2',
      transferCode: 'PB SRC2',
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    };

    map1.set(p1.id, p1);
    map2.set(p2.id, p2);

    const lookup = new MemoryPaymentLookup([
      { payments: map1, transferRecords: recs1 },
      { payments: map2, transferRecords: recs2 },
    ]);

    assert.equal((await lookup.getPayment('p_src1'))?.id, 'p_src1');
    assert.equal((await lookup.getPayment('p_src2'))?.id, 'p_src2');
    assert.equal((await lookup.findPaymentsByTransferCode('PB SRC1')).length, 1);
    assert.equal((await lookup.findPaymentsByTransferCode('PB SRC2')).length, 1);

    const record = transferRecordOf(
      { provider: 'fake', txnId: 't_unmatch', amount: 50_000, content: 'xyz', receivedAt: '2026-10-10T10:00:00.000Z' },
      'needs_review',
    );
    await lookup.saveUnmatchedTransfer(record);
    assert.equal(recs1.has(record.id), true);
    assert.equal(recs2.has(record.id), false);

    // Second call is no-op
    await lookup.saveUnmatchedTransfer(record);
    assert.equal(recs1.size, 1);
  });
});
