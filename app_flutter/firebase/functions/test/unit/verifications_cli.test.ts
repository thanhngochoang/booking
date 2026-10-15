import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { notifyVerificationChange, type VerificationChange } from '@photobooking/domain';
import { overdue, parseArgs, queueLine, runCli, type CliIo } from '../../tools/verifications.js';
import { NOW, readyRecord, verificationWorld } from './verification_support.js';

const HOUR = 3_600_000;
const ago = (h: number) => new Date(NOW.getTime() - h * HOUR).toISOString();

describe('verifications staff CLI', () => {
  let w: ReturnType<typeof verificationWorld>;
  let out: string[];
  let admin: boolean;
  let notified: VerificationChange[];

  const io = (): CliIo => ({
    print: (l) => void out.push(l),
    now: () => NOW,
    show: async (uid) => {
      const v = w.store.verifications.get(uid);
      return v === undefined ? null : { verification: v, identity: null, fileLines: [] };
    },
    isAdmin: async () => admin,
    notify: async (change) => {
      notified.push(change);
      await notifyVerificationChange(w.notify, change);
    },
  });

  beforeEach(() => {
    w = verificationWorld();
    out = [];
    admin = true;
    notified = [];
  });

  it('parseArgs for list/show/approve/reject/revoke/business-approve/business-reject', () => {
    assert.deepEqual(parseArgs(['list']), { command: 'list', uid: null, reason: null, note: null, actor: null });
    assert.deepEqual(parseArgs(['show', 'p1']), { command: 'show', uid: 'p1', reason: null, note: null, actor: null });
    assert.deepEqual(parseArgs(['approve', 'p1', '--actor', 'staff1']), {
      command: 'approve', uid: 'p1', reason: null, note: null, actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['reject', 'p1', 'fake_avatar', '--actor', 'staff1']), {
      command: 'reject', uid: 'p1', reason: 'fake_avatar', note: null, actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['reject', 'p1', 'other', 'Ảnh không phải của bạn', '--actor', 'staff1']), {
      command: 'reject', uid: 'p1', reason: 'other', note: 'Ảnh không phải của bạn', actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['--actor', 'staff1', 'revoke', 'p1', 'Tài khoản bị báo cáo giả mạo']), {
      command: 'revoke', uid: 'p1', reason: null, note: 'Tài khoản bị báo cáo giả mạo', actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['business-approve', 's1', '--actor', 'staff1']), {
      command: 'business-approve', uid: 's1', reason: null, note: null, actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['business-reject', 's1', 'doc_unreadable', '--actor', 'staff1']), {
      command: 'business-reject', uid: 's1', reason: 'doc_unreadable', note: null, actor: 'staff1',
    });
    assert.throws(() => parseArgs([]), /usage/);
    assert.throws(() => parseArgs(['frobnicate', 'p1']), /usage/);
    assert.throws(() => parseArgs(['constructor', 'p1']), /usage/);
    assert.throws(() => parseArgs(['approve']), /missing uid/);
    assert.throws(() => parseArgs(['reject', 'p1']), /needs a reason/);
    assert.throws(() => parseArgs(['business-reject', 's1']), /needs a reason/);
    assert.throws(() => parseArgs(['revoke', 'p1']), /needs a note/);
    assert.throws(() => parseArgs(['approve', 'p1', '--actor']), /--actor needs a uid/);
  });

  it('list marks rows older than 24 h', async () => {
    w.store.verifications.set('p1', readyRecord('p1', { submittedAt: ago(25) }));
    w.store.verifications.set('p2', readyRecord('p2', { submittedAt: ago(3) }));
    w.store.verifications.set(
      's1',
      readyRecord('s1', {
        status: 'approved',
        business: {
          status: 'submitted', kind: 'company', taxCode: '0312345678', name: 'X', address: 'Y', registryStatus: 'active',
          docPath: 'businessDocs/s1/a.jpg', representativeMatched: false, submittedAt: ago(30), decidedAt: null,
          decidedBy: null, rejectReason: null, purgeAfter: null,
        },
      }),
    );
    await runCli(['list'], w.deps, io());
    assert.deepEqual(out, [
      `! p1  identity  individual  ${ago(25)}  waiting 1d 1h`,
      `  p2  identity  individual  ${ago(3)}  waiting 3h`,
      `! s1  business  company  ${ago(30)}  waiting 1d 6h`,
    ]);
    assert.equal(overdue(new Date(ago(24)), NOW), false);
    assert.equal(overdue(new Date(ago(24.01)), NOW), true);
    assert.equal(queueLine(readyRecord('p1', { submittedAt: ago(1) }), 'identity', NOW).startsWith('  p1'), true);
  });

  it('--actor must hold the admin claim', async () => {
    w.store.verifications.set('p1', readyRecord('p1'));
    await assert.rejects(() => runCli(['approve', 'p1'], w.deps, io()), /--actor/);
    admin = false;
    await assert.rejects(() => runCli(['approve', 'p1', '--actor', 'p1'], w.deps, io()), /admin claim/);
    assert.equal(w.store.verifications.get('p1')?.status, 'submitted');
    assert.equal(w.store.audits.length, 0);
    assert.equal(notified.length, 0);
  });

  it('a decision goes through the same use case, audits the actor and notifies', async () => {
    w.store.verifications.set('p1', readyRecord('p1'));
    await runCli(['approve', 'p1', '--actor', 'staff1'], w.deps, io());
    assert.deepEqual(out, ['p1 identity -> approved']);
    assert.equal(w.store.providerFlags.get('p1')?.acceptingOrders, true);
    assert.equal(w.store.audits[0]?.actorId, 'staff1');
    assert.deepEqual(w.notifyStore.rowsOf('p1').map((r) => r.type), ['verification_approved']);

    await runCli(['revoke', 'p1', 'Tài khoản bị báo cáo giả mạo', '--actor', 'staff1'], w.deps, io());
    assert.equal(w.store.providerFlags.get('p1')?.acceptingOrders, false);
    assert.equal(w.store.audits[1]?.note, 'Tài khoản bị báo cáo giả mạo');
    assert.equal(out.at(-1), 'p1 identity -> revoked');
  });

  it('reject passes reason and note; a bad reason is refused by the use case', async () => {
    w.store.verifications.set('p1', readyRecord('p1'));
    await assert.rejects(() => runCli(['reject', 'p1', 'ugly', '--actor', 'staff1'], w.deps, io()), /invalid_argument/);
    await runCli(['reject', 'p1', 'other', 'Ảnh đại diện không rõ mặt', '--actor', 'staff1'], w.deps, io());
    assert.deepEqual(w.store.verifications.get('p1')?.rejectReason, { code: 'other', text: 'Ảnh đại diện không rõ mặt' });
  });

  it('business decisions target the business sub-record', async () => {
    w.store.verifications.set(
      's1',
      readyRecord('s1', {
        status: 'approved',
        business: {
          status: 'submitted', kind: 'company', taxCode: '0312345678', name: 'X', address: 'Y', registryStatus: 'active',
          docPath: 'businessDocs/s1/a.jpg', representativeMatched: false, submittedAt: ago(2), decidedAt: null,
          decidedBy: null, rejectReason: null, purgeAfter: null,
        },
      }),
    );
    await runCli(['business-reject', 's1', 'doc_unreadable', '--actor', 'staff1'], w.deps, io());
    assert.equal(out.at(-1), 's1 business -> rejected');
    assert.ok(w.store.verifications.get('s1')?.business?.purgeAfter);
    assert.deepEqual(w.notifyStore.rowsOf('s1').map((r) => r.type), ['business_rejected']);
  });

  it('a failed notification is reported and the decision stays', async () => {
    w.store.verifications.set('p1', readyRecord('p1'));
    await runCli(['approve', 'p1', '--actor', 'staff1'], w.deps, {
      ...io(),
      notify: () => Promise.reject(new Error('push down')),
    });
    assert.equal(w.store.verifications.get('p1')?.status, 'approved');
    assert.ok(out.some((l) => l.includes('notification failed')));
  });

  it('show prints the record, never the id number', async () => {
    w.store.verifications.set('p1', readyRecord('p1'));
    await runCli(['show', 'p1'], w.deps, {
      ...io(),
      show: async () => ({
        verification: readyRecord('p1'),
        identity: { legalName: 'THO P1', dob: '1995-01-01', method: 'vneid', provider: 'fake' },
        fileLines: ['file: /tmp/x/0-a.jpg'],
      }),
    });
    assert.ok(out[0]?.includes('"status": "submitted"'));
    assert.deepEqual(out.slice(1), ['identity: THO P1  dob 1995-01-01  vneid/fake', 'file: /tmp/x/0-a.jpg']);
    await assert.rejects(() => runCli(['show', 'nobody'], w.deps, io()), /not found/);
  });
});
