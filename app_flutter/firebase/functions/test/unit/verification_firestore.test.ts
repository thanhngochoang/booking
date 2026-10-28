import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';
import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  PLATFORM_PAYEE,
  newSubjectPayment,
  reviewVerification,
  type IdentityRecord,
  type Refund,
  type VerificationRecord,
} from '@photobooking/domain';
import { paymentToFirestore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreVerificationStore,
  identityFromFirestore,
  identityToFirestore,
  verificationFromFirestore,
  verificationToFirestore,
} from '../../src/infra/verification_firestore.js';
import { NOW, feeDepsOf, readyRecord } from './verification_support.js';

const full: VerificationRecord = readyRecord('s1', {
  status: 'approved',
  identitySession: { id: 'sess1', method: 'nfc', startedAt: '2026-10-09T08:00:00.000Z' },
  identityAttempts: { dayKey: '2026-10-10', count: 2 },
  decidedAt: '2026-10-10T11:00:00.000Z',
  decidedBy: 'staff1',
  rejectReason: { code: 'other', text: 'Ảnh đại diện mờ' },
  freeResubmitsLeft: 0,
  nudgedAt: '2026-10-09T09:00:00.000Z',
  business: {
    subject: 'studio',
    status: 'approved',
    kind: 'company',
    taxCode: '0312345678',
    name: 'CÔNG TY TNHH STUDIO THỬ 5678',
    address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
    registryStatus: 'active',
    docPath: 'businessDocs/s1/01J.jpg',
    representativeMatched: false,
    submittedAt: '2026-10-10T12:00:00.000Z',
    decidedAt: '2026-10-10T13:00:00.000Z',
    decidedBy: 'staff1',
    rejectReason: null,
    purgeAfter: '2026-11-09T13:00:00.000Z',
  },
  version: 7,
});

interface Write {
  readonly tx: number;
  readonly op: 'set' | 'create';
  readonly path: string;
  readonly data: DocumentData;
  readonly merge: boolean;
}

/** Just enough Firestore for FirestoreVerificationStore: refs by path, transactions that commit at the end. */
function fakeFirestore(seed: Record<string, DocumentData> = {}) {
  const docs = new Map(Object.entries(seed));
  const writes: Write[] = [];
  const queries: unknown[][][] = [];
  let txCount = 0;
  const ref = (path: string) => ({
    path,
    id: path.split('/').at(-1),
    collection: (c: string) => ({ doc: (d: string) => ref(`${path}/${c}/${d}`) }),
  });
  const query = (calls: unknown[][], name: string) => {
    const q = {
      where: (...a: unknown[]) => (calls.push(['where', ...a]), q),
      orderBy: (...a: unknown[]) => (calls.push(['orderBy', ...a]), q),
      limit: (n: number) => (calls.push(['limit', n]), q),
      get: async () => ({
        docs: [...docs.entries()]
          .filter(([p]) => p.startsWith(`${name}/`) && p.split('/').length === 2)
          .map(([p, d]) => ({ id: p.split('/')[1], data: () => d })),
      }),
      doc: (d: string) => ref(`${name}/${d}`),
    };
    return q;
  };
  const firestore = {
    collection: (name: string) => {
      const calls: unknown[][] = [['collection', name]];
      queries.push(calls);
      return query(calls, name);
    },
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
      const id = (txCount += 1);
      const staged: Write[] = [];
      const tx = {
        // A document by its path, or a query (fee payments of a uid) run as the query's own get().
        get: async (r: { path?: string; get?: () => Promise<unknown> }) =>
          r.path === undefined && r.get !== undefined
            ? r.get()
            : { exists: docs.has(r.path ?? ''), data: () => docs.get(r.path ?? '') },
        set: (r: { path: string }, data: DocumentData, opts?: { merge?: boolean }) =>
          void staged.push({ tx: id, op: 'set', path: r.path, data, merge: opts?.merge === true }),
        create: (r: { path: string }, data: DocumentData) => {
          if (docs.has(r.path)) throw new Error(`ALREADY_EXISTS ${r.path}`);
          staged.push({ tx: id, op: 'create', path: r.path, data, merge: false });
        },
      };
      const result = await fn(tx);
      for (const w of staged) {
        docs.set(w.path, w.merge ? { ...(docs.get(w.path) ?? {}), ...w.data } : w.data);
        writes.push(w);
      }
      return result;
    },
  };
  return { firestore: firestore as unknown as Firestore, docs, writes, queries };
}

const whereOf = (calls: unknown[][] | undefined) =>
  (calls ?? []).filter((c) => c[0] === 'where').map((c) => [c[1], c[2], c[3] instanceof Timestamp ? c[3].toDate().toISOString() : c[3]]);

describe('verification Firestore mapping', () => {
  it('verification maps to and from Firestore (Timestamps ↔ ISO)', () => {
    const doc = verificationToFirestore(full);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.ok(doc.updatedAt instanceof Timestamp);
    assert.ok(doc.submittedAt instanceof Timestamp);
    assert.ok(doc.nudgedAt instanceof Timestamp);
    assert.ok(doc.steps.phone.doneAt instanceof Timestamp);
    assert.ok(doc.steps.identity.checkedAt instanceof Timestamp);
    assert.ok(doc.identitySession.startedAt instanceof Timestamp);
    assert.ok(doc.business.purgeAfter instanceof Timestamp);
    assert.ok(doc.business.submittedAt instanceof Timestamp);
    assert.equal(doc.steps.fee, null);
    assert.equal(doc.identityAttempts.dayKey, '2026-10-10');
    assert.deepEqual(verificationFromFirestore(doc), full);
  });

  it('a fresh record keeps its nulls and the steps.fee field (#203 needs no migration)', () => {
    const fresh = readyRecord('p1', {
      status: 'in_progress',
      steps: { phone: null, fee: null, identity: null, rules: null },
      submittedAt: null,
    });
    const doc = verificationToFirestore(fresh);
    assert.ok('fee' in doc.steps);
    assert.equal(doc.business, null);
    assert.equal(doc.submittedAt, null);
    assert.deepEqual(verificationFromFirestore(doc), fresh);
    assert.equal(verificationFromFirestore(undefined), null);
  });

  it('an old doc without feeAttempt reads it as 1', () => {
    const doc = verificationToFirestore(full);
    delete doc.feeAttempt;
    assert.equal(verificationFromFirestore(doc)?.feeAttempt, 1);
  });

  it('the business record keeps its subject; an old doc without one reads as a studio (S21.04 for organizers)', () => {
    const organizer: VerificationRecord = {
      ...full,
      uid: 'org1',
      business: { ...(full.business as NonNullable<VerificationRecord['business']>), subject: 'organizer', status: 'submitted' },
    };
    const doc = verificationToFirestore(organizer);
    assert.equal(doc.business.subject, 'organizer');
    assert.deepEqual(verificationFromFirestore(doc), organizer);
    delete doc.business.subject;
    assert.equal(verificationFromFirestore(doc)?.business?.subject, 'studio');
  });

  it('identity maps both ways and holds no plain id number', () => {
    const r: IdentityRecord = {
      legalName: 'NGUYỄN MINH TRÍ',
      dob: '1995-01-01',
      gender: null,
      idNumberEnc: 'v1:a:b:c',
      idHash: 'abc',
      method: 'vneid',
      provider: 'fake',
      providerRef: 'fake_ref_p1',
      verifiedAt: NOW.toISOString(),
    };
    const doc = identityToFirestore(r);
    assert.ok(doc.verifiedAt instanceof Timestamp);
    assert.deepEqual(Object.keys(doc).filter((k) => /^idNumber$/.test(k)), []);
    assert.deepEqual(identityFromFirestore(doc), r);
  });
});

describe('FirestoreVerificationStore', () => {
  it('approve writes verifications and photographers in one batch', async () => {
    const { firestore, writes } = fakeFirestore({
      'verifications/p1': verificationToFirestore(readyRecord('p1')),
      'photographers/p1': { onboardingComplete: true, verified: false, acceptingOrders: false },
    });
    const store = new FirestoreVerificationStore(firestore);
    await reviewVerification(
      { store, authPhones: { verifiedPhoneOf: async () => null }, identity: null, vault: null, taxCodes: null, feeRequired: false, ...feeDepsOf(), clock: { now: () => NOW }, ids: { newId: () => 'a1' } },
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'approve' },
    );
    assert.deepEqual(
      writes.map((w) => [w.tx, w.path]),
      [
        [1, 'verifications/p1'],
        [1, 'photographers/p1'],
        [1, 'verificationAudit/a1'],
      ],
    );
    const flags = writes.find((w) => w.path === 'photographers/p1');
    assert.equal(flags?.merge, true);
    assert.equal(flags?.data.verified, true);
    assert.equal(flags?.data.acceptingOrders, true);
    assert.ok(flags?.data.verifiedAt instanceof Timestamp);
    assert.equal(writes[0]?.merge, false);
    assert.equal(writes[0]?.data.status, 'approved');
    assert.equal(writes[2]?.data.actorId, 'staff1');
  });

  it('approve of a provider who has not finished setup leaves acceptingOrders false', async () => {
    const { firestore, writes } = fakeFirestore({
      'verifications/p1': verificationToFirestore(readyRecord('p1')),
      'photographers/p1': { onboardingComplete: false },
    });
    await reviewVerification(
      { store: new FirestoreVerificationStore(firestore), authPhones: { verifiedPhoneOf: async () => null }, identity: null, vault: null, taxCodes: null, feeRequired: false, ...feeDepsOf(), clock: { now: () => NOW }, ids: { newId: () => 'a1' } },
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'approve' },
    );
    const flags = writes.find((w) => w.path === 'photographers/p1');
    assert.equal(flags?.data.verified, true);
    assert.equal(flags?.data.acceptingOrders, false);
  });

  const businessDeps = (store: FirestoreVerificationStore) => ({
    store, authPhones: { verifiedPhoneOf: async () => null }, identity: null, vault: null, taxCodes: null, feeRequired: false,
    ...feeDepsOf(), clock: { now: () => NOW }, ids: { newId: () => 'a1' },
  });
  const submitted = (uid: string, subject: 'studio' | 'organizer'): VerificationRecord => ({
    ...(readyRecord(uid, { status: 'approved' })),
    business: { ...(full.business as NonNullable<VerificationRecord['business']>), subject, status: 'submitted', decidedAt: null, decidedBy: null, purgeAfter: null },
  });

  it("approval of an organizer's record sets organizers/{uid}.businessVerified and does not write photographers/{uid}", async () => {
    const { firestore, writes } = fakeFirestore({
      'verifications/org1': verificationToFirestore(submitted('org1', 'organizer')),
      'organizers/org1': { status: 'active', businessVerified: false },
    });
    await reviewVerification(businessDeps(new FirestoreVerificationStore(firestore)), { uid: 'staff1', isAdmin: true }, {
      uid: 'org1', target: 'business', action: 'approve',
    });
    assert.deepEqual(
      writes.map((w) => [w.path, w.merge]),
      [['verifications/org1', false], ['organizers/org1', true], ['verificationAudit/a1', false]],
    );
    const flags = writes.find((w) => w.path === 'organizers/org1');
    assert.equal(flags?.data.businessVerified, true);
    assert.ok(flags?.data.updatedAt instanceof Timestamp);
    assert.equal(writes.some((w) => w.path.startsWith('photographers/')), false);
    assert.equal(writes[0]?.data.business.subject, 'organizer');
  });

  it("a studio's approval behaves as today: photographers/{uid} is patched and no organizers document is written", async () => {
    const { firestore, writes } = fakeFirestore({
      'verifications/s1': verificationToFirestore(submitted('s1', 'studio')),
      'photographers/s1': { providerType: 'studio', onboardingComplete: true, verified: true },
      'organizers/s1': { status: 'active', businessVerified: false },
    });
    await reviewVerification(businessDeps(new FirestoreVerificationStore(firestore)), { uid: 'staff1', isAdmin: true }, {
      uid: 's1', target: 'business', action: 'approve',
    });
    assert.deepEqual(
      writes.map((w) => [w.path, w.merge]),
      [['verifications/s1', false], ['photographers/s1', true], ['verificationAudit/a1', false]],
    );
    assert.deepEqual(writes[1]?.data, { businessVerified: true });
  });

  it('getOrganizer reads organizers/{uid}: its status and business flag; missing is null', async () => {
    const { firestore } = fakeFirestore({
      'organizers/org1': { status: 'active', businessVerified: true },
      'organizers/org2': { status: 'suspended' },
      'organizers/org3': { status: 'banned' },
    });
    await new FirestoreVerificationStore(firestore).runTransaction(async (tx) => {
      assert.deepEqual(await tx.getOrganizer('org1'), { status: 'active', businessVerified: true });
      assert.deepEqual(await tx.getOrganizer('org2'), { status: 'suspended', businessVerified: false });
      assert.equal(await tx.getOrganizer('org3'), null);
      assert.equal(await tx.getOrganizer('nobody'), null);
    });
  });

  it('reads the provider, contact and identity from their documents', async () => {
    const { firestore } = fakeFirestore({
      'photographers/s1': { providerType: 'studio', onboardingComplete: true, verified: true, businessVerified: true },
      'users/s1/private/contact': { phone: '+84903999999', phoneVerified: true },
      'identity_hashes/h1': { uid: 's1' },
    });
    const store = new FirestoreVerificationStore(firestore);
    await store.runTransaction(async (tx) => {
      assert.deepEqual(await tx.getProvider('s1'), { providerType: 'studio', onboardingComplete: true, verified: true, businessVerified: true });
      assert.equal(await tx.getProvider('nobody'), null);
      assert.deepEqual(await tx.getContact('s1'), { phone: '+84903999999', phoneVerified: true });
      assert.deepEqual(await tx.getContact('nobody'), { phone: null, phoneVerified: false });
      assert.equal(await tx.identityOwner('h1'), 's1');
      assert.equal(await tx.identityOwner('h2'), null);
      assert.equal(await tx.getIdentity('s1'), null);
    });
  });

  it('phone, identity and hash guard writes go to their documents; the guard is created, never overwritten', async () => {
    const { firestore, writes } = fakeFirestore({ 'identity_hashes/taken': { uid: 'p9' } });
    const store = new FirestoreVerificationStore(firestore);
    await store.runTransaction(async (tx) => {
      tx.setPhoneVerified('p1');
      tx.putIdentityHash('h1', 'p1');
    });
    assert.deepEqual(
      writes.map((w) => [w.op, w.path, w.merge]),
      [
        ['set', 'users/p1/private/contact', true],
        ['create', 'identity_hashes/h1', false],
      ],
    );
    assert.deepEqual(writes[0]?.data, { phoneVerified: true });
    await assert.rejects(() => store.runTransaction(async (tx) => tx.putIdentityHash('taken', 'p1')), /ALREADY_EXISTS/);
  });

  it('the fee members read and write the shared payment collections with the shared mappings (#203)', async () => {
    const fee = newSubjectPayment({
      id: '01JA0000000000000000000001',
      subjectType: 'verification_fee',
      subjectId: 'p1',
      payerId: 'p1',
      payeeId: PLATFORM_PAYEE,
      amount: 99_000,
      method: 'bank_qr',
      provider: 'fake',
      idempotencyKey: 'vfee_p1_1_bank_qr',
      now: NOW,
      expiresAt: new Date(NOW.getTime() + 15 * 60_000),
    });
    const { firestore, writes, queries } = fakeFirestore({ [`payments/${fee.id}`]: paymentToFirestore(fee) });
    const store = new FirestoreVerificationStore(firestore);
    const at = NOW.toISOString();
    const refund: Refund = {
      id: 'r1', paymentId: fee.id, subjectType: 'verification_fee', amount: 99_000, percent: 100, status: 'pending',
      method: 'gateway', attempts: 0, manual: false, fromEscrow: true, reason: 'duplicate_verification_fee', createdAt: at, updatedAt: at,
    };

    await store.runTransaction(async (tx) => {
      const mine = await tx.feePaymentsOf('p1');
      assert.deepEqual(mine.map((p) => [p.id, p.subjectType, p.payeeId, p.amount, p.idempotencyKey]), [
        [fee.id, 'verification_fee', 'platform', 99_000, 'vfee_p1_1_bank_qr'],
      ]);
      assert.equal((await tx.getPayment(fee.id))?.transferCode, fee.transferCode);
      assert.equal(await tx.getPayment('nope'), null);
      assert.equal(await tx.getRefund('r1'), null);
      assert.equal(await tx.getTransferRecord('fake_t1'), null);
      tx.putPayment({ ...fee, status: 'paid', escrowStatus: 'released', releasedAt: at });
      tx.putRefund(refund);
      tx.addLedgerEntry({ id: 'l1', type: 'fee_charged', paymentId: fee.id, accountOwnerId: 'platform_revenue', amount: 99_000, at });
      tx.putTransferRecord({ id: 'fake_t1', provider: 'fake', txnId: 't1', receivedAt: at, outcome: 'paid', paymentId: fee.id });
    });

    const query = queries.find((q) => q.some((c) => c[0] === 'where'));
    assert.deepEqual(query?.[0], ['collection', 'payments']);
    assert.deepEqual(whereOf(query), [
      ['subjectType', '==', 'verification_fee'],
      ['subjectId', '==', 'p1'],
    ]);
    assert.deepEqual(
      writes.map((w) => [w.path, w.merge]),
      [
        [`payments/${fee.id}`, false],
        ['refunds/r1', false],
        ['ledger_entries/l1', false],
        ['payment_notifications/fake_t1', false],
      ],
    );
    assert.equal(writes[0]?.data.escrowStatus, 'released');
    assert.ok(writes[0]?.data.releasedAt instanceof Timestamp);
    assert.equal(writes[1]?.data.subjectType, 'verification_fee');
    assert.equal(writes[2]?.data.type, 'fee_charged');
    // Read back through the same mappings.
    await store.runTransaction(async (tx) => {
      assert.equal((await tx.getRefund('r1'))?.reason, 'duplicate_verification_fee');
      assert.equal((await tx.getTransferRecord('fake_t1'))?.paymentId, fee.id);
    });
  });

  it('dueForNudge asks for in_progress, never nudged, unchanged since the cutoff', async () => {
    const { firestore, queries } = fakeFirestore();
    const cutoff = new Date('2026-10-09T10:00:00.000Z');
    await new FirestoreVerificationStore(firestore).dueForNudge(cutoff, 50);
    assert.deepEqual(queries[0]?.[0], ['collection', 'verifications']);
    assert.deepEqual(whereOf(queries[0]), [
      ['status', '==', 'in_progress'],
      ['nudgedAt', '==', null],
      ['updatedAt', '<=', cutoff.toISOString()],
    ]);
    assert.deepEqual(queries[0]?.at(-1), ['limit', 50]);
  });

  it('the staff queues are submitted records, oldest first', async () => {
    const { firestore, queries } = fakeFirestore();
    const store = new FirestoreVerificationStore(firestore);
    await store.queue('identity', 50);
    await store.queue('business', 50);
    assert.deepEqual(queries[0]?.slice(1), [
      ['where', 'status', '==', 'submitted'],
      ['orderBy', 'submittedAt', 'asc'],
      ['limit', 50],
    ]);
    assert.deepEqual(queries[1]?.slice(1), [
      ['where', 'business.status', '==', 'submitted'],
      ['orderBy', 'business.submittedAt', 'asc'],
      ['limit', 50],
    ]);
  });

  it('the business purge finds due photos and clears the record only while the path is unchanged', async () => {
    const due = verificationToFirestore(full);
    const { firestore, queries, docs } = fakeFirestore({ 'verifications/s1': due });
    const store = new FirestoreVerificationStore(firestore);
    const later = new Date('2026-11-10T00:00:00.000Z');
    assert.deepEqual(await store.findDueBusinessPurges(later, 200), [{ uid: 's1', docPath: 'businessDocs/s1/01J.jpg' }]);
    assert.deepEqual(whereOf(queries[0]), [['business.purgeAfter', '<=', later.toISOString()]]);

    await store.clearBusinessDoc('s1', 'businessDocs/s1/other.jpg', later);
    assert.equal(verificationFromFirestore(docs.get('verifications/s1'))?.business?.docPath, 'businessDocs/s1/01J.jpg');

    await store.clearBusinessDoc('s1', 'businessDocs/s1/01J.jpg', later);
    const after = verificationFromFirestore(docs.get('verifications/s1'));
    assert.equal(after?.business?.docPath, null);
    assert.equal(after?.business?.purgeAfter, null);
    assert.equal(after?.business?.status, 'approved');
    assert.equal(after?.version, full.version + 1);
  });

  it('the verification queries have their composite indexes', () => {
    const json = JSON.parse(readFileSync(new URL('../../../firestore.indexes.json', import.meta.url), 'utf8')) as {
      indexes: { collectionGroup: string; queryScope: string; fields: { fieldPath: string; order: string }[] }[];
    };
    const shapes = json.indexes
      .filter((i) => i.collectionGroup === 'verifications' && i.queryScope === 'COLLECTION')
      .map((i) => i.fields.map((f) => `${f.fieldPath} ${f.order}`).join(', '));
    assert.ok(shapes.includes('status ASCENDING, nudgedAt ASCENDING, updatedAt ASCENDING'), shapes.join(' | '));
    assert.ok(shapes.includes('status ASCENDING, submittedAt ASCENDING'), shapes.join(' | '));
    assert.ok(shapes.includes('business.status ASCENDING, business.submittedAt ASCENDING'), shapes.join(' | '));
  });
});
