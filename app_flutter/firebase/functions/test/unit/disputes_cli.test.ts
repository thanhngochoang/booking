import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { openDispute, type SupportMessage } from '@photobooking/domain';
import { HELP, SEND_FAILED_EXIT, guardEnv, parseArgs, runCli, type DisputesCliIo } from '../../tools/disputes.js';
import {
  createDisputeWorld,
  hoursFrom,
  openInput,
  seedApprovedBooking,
  type DisputeWorld,
} from '../../../../../packages/domain/test/support/dispute_world.js';

// `npm run disputes` (S18, #142 Decision 10): staff list, read and decide disputes until the S23.01
// dashboard exists; `resolve` runs the same `resolveDispute` as the callable, then sends the refund.

const LOCAL = { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', GCLOUD_PROJECT: 'demo-nag' };

function cli(w: DisputeWorld | null) {
  const out: string[] = [];
  let opened = 0;
  const io: DisputesCliIo = {
    print: (l) => void out.push(l),
    deps: async () => {
      opened += 1;
      if (w === null) throw new Error('no world');
      return w.deps as Awaited<ReturnType<DisputesCliIo['deps']>>;
    },
    isAdmin: async (uid) => uid === 'staff1',
  };
  return { out, io, opened: () => opened };
}

async function openedWorld(): Promise<DisputeWorld> {
  const w = createDisputeWorld();
  seedApprovedBooking(w);
  await openDispute(w.deps, 'c1', openInput());
  return w;
}

describe('disputes CLI', () => {
  it('parseArgs list/show/resolve release|refund|split', () => {
    assert.deepEqual(parseArgs(['list']), { command: 'list', status: 'open' });
    assert.deepEqual(parseArgs(['list', 'resolved']), { command: 'list', status: 'resolved' });
    assert.deepEqual(parseArgs(['show', 'd1']), { command: 'show', disputeId: 'd1' });
    assert.deepEqual(parseArgs(['resolve', 'd1', 'release', 'Ảnh đã giao đủ', '--actor', 'staff1']), {
      command: 'resolve',
      disputeId: 'd1',
      outcome: 'release',
      refundPercent: null,
      note: 'Ảnh đã giao đủ',
      actor: 'staff1',
    });
    assert.deepEqual(parseArgs(['resolve', 'd1', 'refund', 'Thợ không đến', '--actor', 'staff1']), {
      command: 'resolve',
      disputeId: 'd1',
      outcome: 'refund',
      refundPercent: null,
      note: 'Thợ không đến',
      actor: 'staff1',
    });
    // --actor may come anywhere.
    assert.deepEqual(parseArgs(['--actor', 'staff1', 'resolve', 'd1', 'split', '40', 'Thiếu một phần ảnh']), {
      command: 'resolve',
      disputeId: 'd1',
      outcome: 'split',
      refundPercent: 40,
      note: 'Thiếu một phần ảnh',
      actor: 'staff1',
    });
    assert.throws(() => parseArgs([]), /usage: disputes/);
    assert.throws(() => parseArgs(['list', 'pending']), /usage: disputes/);
    assert.throws(() => parseArgs(['show']), /missing dispute id/);
    assert.throws(() => parseArgs(['resolve', 'd1', 'keep', 'Ghi chú', '--actor', 'staff1']), /release, refund or split/);
    assert.throws(() => parseArgs(['resolve', 'd1', 'release', 'Ghi chú', '--actor']), /--actor needs a uid/);
    // A flag where the uid should be is a mistake, never a uid.
    assert.throws(() => parseArgs(['resolve', 'd1', 'release', 'Ghi chú', '--actor', '--help']), /--actor needs a uid/);
    assert.throws(() => parseArgs(['--actor', '--note', 'resolve', 'd1', 'release', 'Ghi chú']), /--actor needs a uid/);
  });

  it('split needs 1–99', () => {
    for (const bad of ['0', '100', '40.5', '-3', 'abc']) {
      assert.throws(() => parseArgs(['resolve', 'd1', 'split', bad, 'Thiếu một phần ảnh', '--actor', 'staff1']), /split needs a percent 1-99/, bad);
    }
    assert.throws(() => parseArgs(['resolve', 'd1', 'split', 'Thiếu một phần ảnh', '--actor', 'staff1']), /split needs a percent 1-99/);
    assert.equal((parseArgs(['resolve', 'd1', 'split', '1', 'Ghi chú đủ', '--actor', 's']) as { refundPercent: number }).refundPercent, 1);
    assert.equal((parseArgs(['resolve', 'd1', 'split', '99', 'Ghi chú đủ', '--actor', 's']) as { refundPercent: number }).refundPercent, 99);
    // release and refund take no percent: a number there is the note, which the domain then checks.
    assert.throws(() => parseArgs(['resolve', 'd1', 'refund', '40', 'Ghi chú', '--actor', 's']), /refund takes no percent/);
  });

  it('resolve needs a note and --actor', async () => {
    assert.throws(() => parseArgs(['resolve', 'd1', 'release']), /resolve needs a note/);
    assert.throws(() => parseArgs(['resolve', 'd1', 'split', '40']), /resolve needs a note/);

    const w = await openedWorld();
    const noActor = cli(w);
    await assert.rejects(runCli(['resolve', 'd1', 'release', 'Ảnh đã giao đủ'], LOCAL, noActor.io), /resolve needs --actor <uid>/);
    assert.equal(noActor.opened(), 0);

    const notAdmin = cli(w);
    await assert.rejects(
      runCli(['resolve', 'd1', 'release', 'Ảnh đã giao đủ', '--actor', 'c1'], LOCAL, notAdmin.io),
      /c1 does not have the admin claim/,
    );
    assert.equal(notAdmin.opened(), 0);
    assert.equal(w.store.disputes.get('d1')?.status, 'open');
  });

  it('--help prints HELP', async () => {
    const t = cli(null);
    assert.equal(await runCli(['--help'], {}, t.io), 0);
    assert.deepEqual(t.out, [HELP]);
    assert.match(HELP, /usage: disputes list \[open\|resolved\] \| show <id> \| resolve <id> release\|refund "<note>" --actor <uid>/);
    assert.match(HELP, /resolve <id> split <percent> "<note>" --actor <uid>/);
    assert.match(HELP, /staffRole = admin/);
    assert.match(HELP, /GOOGLE_APPLICATION_CREDENTIALS/);
    assert.match(HELP, /PAYOUT_ACCOUNT_KEY/);
    assert.equal(t.opened(), 0);
  });

  it('guardEnv: no emulator host is the real project, which needs GCLOUD_PROJECT and PAYOUT_ACCOUNT_KEY', () => {
    const real = { GOOGLE_APPLICATION_CREDENTIALS: '/keys/sa.json', GCLOUD_PROJECT: 'booking-prod-1', PAYOUT_ACCOUNT_KEY: 'a2V5' };
    assert.equal(guardEnv(real), 'project');
    assert.throws(() => guardEnv({ ...real, GCLOUD_PROJECT: '' }), /GCLOUD_PROJECT is not set/);
    assert.throws(() => guardEnv({ ...real, PAYOUT_ACCOUNT_KEY: undefined }), /set PAYOUT_ACCOUNT_KEY/);
  });

  it('guardEnv: any emulator host means every one local and no credentials', () => {
    assert.equal(guardEnv(LOCAL), 'emulator');
    // The emulator key is the default: PAYOUT_ACCOUNT_KEY is not needed here.
    assert.equal(guardEnv({ ...LOCAL, PAYOUT_ACCOUNT_KEY: undefined }), 'emulator');
    assert.throws(() => guardEnv({ ...LOCAL, FIREBASE_AUTH_EMULATOR_HOST: undefined }), /Refusing to run: FIREBASE_AUTH_EMULATOR_HOST/);
    assert.throws(
      () => guardEnv({ ...LOCAL, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' }),
      /Refusing to run: FIRESTORE_EMULATOR_HOST/,
    );
    assert.throws(() => guardEnv({ ...LOCAL, GOOGLE_APPLICATION_CREDENTIALS: '/keys/sa.json' }), /GOOGLE_APPLICATION_CREDENTIALS is set/);
  });

  it('refuses a mixed or incomplete environment before opening the deps', async () => {
    const t = cli(null);
    await assert.rejects(runCli(['list'], {}, t.io), /GCLOUD_PROJECT is not set/);
    await assert.rejects(runCli(['list'], { GCLOUD_PROJECT: 'booking-prod-1' }, t.io), /set PAYOUT_ACCOUNT_KEY/);
    await assert.rejects(
      runCli(['resolve', 'd1', 'refund', 'Thợ không đến', '--actor', 'staff1'], { ...LOCAL, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' }, t.io),
      /Refusing to run: FIRESTORE_EMULATOR_HOST/,
    );
    assert.equal(t.opened(), 0);
  });

  it('list prints id, created date, subject title, amount held and status', async () => {
    const w = await openedWorld();
    const t = cli(w);
    assert.equal(await runCli(['list'], LOCAL, t.io), 0);
    assert.equal(t.out.length, 1);
    const line = t.out[0] ?? '';
    assert.match(line, /^d1 {2}2026-10-20T10:00:00\.000Z {2}booking {2}Minh Trí · Chân dung {2}held 500\.000₫ {2}open$/);

    const none = cli(w);
    assert.equal(await runCli(['list', 'resolved'], LOCAL, none.io), 0);
    assert.deepEqual(none.out, ['no resolved disputes']);
  });

  it('list says when it shows only the first 50', async () => {
    const w = await openedWorld();
    const d1 = w.store.disputes.get('d1');
    assert.ok(d1);
    const exactly = cli(w);
    for (let i = 2; i <= 50; i += 1) w.store.disputes.set(`d${i}`, { ...d1, id: `d${i}`, createdAt: hoursFrom(i).toISOString() });
    assert.equal(await runCli(['list'], LOCAL, exactly.io), 0);
    assert.equal(exactly.out.length, 50);
    assert.equal(exactly.out.some((l) => l.startsWith('showing first')), false);

    w.store.disputes.set('d51', { ...d1, id: 'd51', createdAt: hoursFrom(51).toISOString() });
    const cut = cli(w);
    assert.equal(await runCli(['list'], LOCAL, cut.io), 0);
    assert.equal(cut.out.length, 51);
    assert.match(cut.out[49] ?? '', /^d50 /);
    assert.equal(cut.out[50], 'showing first 50 (oldest first)');
  });

  it('show prints the dispute, its evidence paths and the last 30 thread messages, oldest first', async () => {
    const w = await openedWorld();
    // 2 messages from openDispute + 33 more = 35; the oldest 5 are left out.
    await w.store.runTransaction(async (tx) => {
      for (let i = 1; i <= 33; i += 1) {
        const m: SupportMessage = {
          id: `m${i}`,
          threadId: 'dispute_d1',
          senderId: i % 2 === 0 ? 'c1' : 'p1',
          senderRole: i % 2 === 0 ? 'customer' : 'provider',
          senderName: i % 2 === 0 ? 'An' : 'Minh Trí',
          body: `tin ${i}`,
          createdAt: hoursFrom(i / 60).toISOString(),
        };
        tx.addMessage(m);
      }
    });
    const t = cli(w);
    assert.equal(await runCli(['show', 'd1'], LOCAL, t.io), 0);
    const text = t.out.join('\n');
    assert.match(text, /"id": "d1"/);
    assert.match(text, /"status": "open"/);
    assert.ok(t.out.includes('evidence: disputeEvidence/c1/d1/f1.jpg'));
    const messages = t.out.filter((l) => l.startsWith('['));
    assert.equal(messages.length, 30);
    assert.match(messages[0] ?? '', /\] customer \(An\): tin 4$/);
    assert.match(messages[29] ?? '', /\] provider \(Minh Trí\): tin 33$/);

    const missing = cli(w);
    assert.equal(await runCli(['show', 'nope'], LOCAL, missing.io), 1);
    assert.deepEqual(missing.out, ['no dispute nope']);
  });

  it('resolve split runs resolveDispute, then sends the refund once', async () => {
    const w = await openedWorld();
    const t = cli(w);
    assert.equal(await runCli(['resolve', 'd1', 'split', '40', 'Thiếu một phần ảnh', '--actor', 'staff1'], LOCAL, t.io), 0);

    const d = w.store.disputes.get('d1');
    assert.equal(d?.status, 'resolved');
    assert.equal(d?.outcome?.kind, 'split');
    assert.equal(d?.outcome?.decidedBy, 'staff1');
    assert.equal(d?.outcome?.refundAmount, 200_000);
    assert.equal(d?.outcome?.releaseAmount, 300_000);
    const refundId = d?.outcome?.refundId ?? '';
    assert.deepEqual(w.gateway.refundCalls, [refundId]);
    assert.equal(w.store.refunds.get(refundId)?.status, 'done');
    assert.deepEqual(t.out, ['d1 -> resolved split: refund 200.000₫, release 300.000₫', `refund ${refundId}: done`]);

    // A second decision is refused by the domain: printed, exit 1, nothing sent again.
    const again = cli(w);
    assert.equal(await runCli(['resolve', 'd1', 'refund', 'Hoàn toàn bộ', '--actor', 'staff1'], LOCAL, again.io), 1);
    assert.deepEqual(again.out, ['refused: conflict']);
    assert.deepEqual(w.gateway.refundCalls, [refundId]);
  });

  it('resolve release moves no refund and sends nothing', async () => {
    const w = await openedWorld();
    const t = cli(w);
    assert.equal(await runCli(['resolve', 'd1', 'release', 'Ảnh đã giao đủ', '--actor', 'staff1'], LOCAL, t.io), 0);
    assert.deepEqual(t.out, ['d1 -> resolved release: refund 0₫, release 500.000₫']);
    assert.deepEqual(w.gateway.refundCalls, []);
  });

  it('a send error after the decision commit prints "decision saved", exits 2 and keeps the decision', async () => {
    const w = await openedWorld();
    // resolveDispute runs two transactions and the CLI reads the payment in a third; the send's first read fails.
    const run = w.store.runTransaction.bind(w.store);
    let calls = 0;
    w.store.runTransaction = (fn) => {
      calls += 1;
      return calls >= 4 ? Promise.reject(new Error('unavailable')) : run(fn);
    };
    const t = cli(w);
    assert.equal(await runCli(['resolve', 'd1', 'refund', 'Thợ không giao ảnh', '--actor', 'staff1'], LOCAL, t.io), SEND_FAILED_EXIT);
    const d = w.store.disputes.get('d1');
    assert.equal(d?.status, 'resolved');
    const refundId = d?.outcome?.refundId ?? '';
    assert.equal(w.store.refunds.get(refundId)?.status, 'pending');
    assert.deepEqual(w.gateway.refundCalls, []);
    assert.deepEqual(t.out, [
      'd1 -> resolved refund: refund 500.000₫, release 0₫',
      `refund ${refundId}: decision saved; refund left pending for re-send (unavailable)`,
    ]);
  });

  it('the same resolve again after a lost answer prints the stored outcome and sends nothing new', async () => {
    const w = await openedWorld();
    const first = cli(w);
    const argv = ['resolve', 'd1', 'split', '40', 'Thiếu một phần ảnh', '--actor', 'staff1'];
    assert.equal(await runCli(argv, LOCAL, first.io), 0);
    const again = cli(w);
    assert.equal(await runCli(argv, LOCAL, again.io), 0);
    const refundId = w.store.disputes.get('d1')?.outcome?.refundId ?? '';
    assert.deepEqual(again.out, ['d1 -> resolved split: refund 200.000₫, release 300.000₫', `refund ${refundId}: done`]);
    assert.deepEqual(w.gateway.refundCalls, [refundId]);
  });

  it('a refund the gateway cannot take now stays pending and the CLI says so', async () => {
    const w = await openedWorld();
    w.gateway.refundThrowCount = 1;
    const t = cli(w);
    assert.equal(await runCli(['resolve', 'd1', 'refund', 'Thợ không giao ảnh', '--actor', 'staff1'], LOCAL, t.io), 0);
    const refundId = w.store.disputes.get('d1')?.outcome?.refundId ?? '';
    assert.equal(w.store.refunds.get(refundId)?.status, 'pending');
    assert.deepEqual(t.out, ['d1 -> resolved refund: refund 500.000₫, release 0₫', `refund ${refundId}: pending`]);
  });
});
