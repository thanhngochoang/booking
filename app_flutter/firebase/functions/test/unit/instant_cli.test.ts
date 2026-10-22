import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { CLI_MEET_NAME, USAGE, parseInstantArgs, runInstantCli, type InstantCliIo } from '../../tools/instant.js';
import { createInstantWorld, type InstantWorld } from '../../../../../packages/domain/test/support/instant_world.js';

// `npm run instant` (#140 Decision 29): creates a request with one offer for an online photographer
// on the emulators, so S14.02/S14.03 can be checked before the customer app exists.

const LOCAL = { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', GCLOUD_PROJECT: 'demo-nag' };

function cli(w: InstantWorld) {
  const out: string[] = [];
  let opened = 0;
  const io: InstantCliIo = {
    print: (l) => void out.push(l),
    deps: async () => {
      opened += 1;
      return w.deps;
    },
  };
  return { out, io, opened: () => opened };
}

describe('instant CLI', () => {
  it('refuses without emulator env', async () => {
    const w = createInstantWorld();
    const t = cli(w);
    await assert.rejects(runInstantCli(['offer', '--photographer', 'p1'], { GCLOUD_PROJECT: 'demo-nag' }, t.io), /Refusing to run/);
    await assert.rejects(
      runInstantCli(['status', 'ir_1'], { ...LOCAL, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' }, t.io),
      /Refusing to run: FIRESTORE_EMULATOR_HOST/,
    );
    assert.equal(t.opened(), 0);
    assert.equal(w.store.requests.size, 0);
  });

  it('offer creates a request and one offer for an online photographer', async () => {
    const w = createInstantWorld();
    w.customer('seed-customer-lan', { name: 'Lan (seed)' });
    const t = cli(w);
    assert.equal(await runInstantCli(['offer', '--photographer', 'p3'], LOCAL, t.io), 0);
    const [request] = [...w.store.requests.values()];
    assert.ok(request !== undefined);
    assert.equal(w.store.requests.size, 1);
    assert.equal(request.customerId, 'seed-customer-lan');
    assert.equal(request.status, 'searching');
    assert.equal(request.meetPoint.name, CLI_MEET_NAME);
    assert.equal(request.packageCode, 'p60');
    assert.equal(request.genre, 'portrait');
    // 500 m north of the photographer.
    const p3 = w.store.presences.get('p3');
    assert.ok(Math.abs(request.meetPoint.lat - (p3?.lat ?? 0) - 0.5 / 111.19508) < 1e-9);
    const offers = w.store.offersOf('p3');
    assert.equal(offers.length, 1);
    assert.equal([...w.store.offers.values()].length, 1);
    assert.deepEqual(t.out, [`request ${request.id}`, `offer ${offers[0]?.id}`]);

    // status prints the request and its rows.
    const s = cli(w);
    assert.equal(await runInstantCli(['status', request.id], LOCAL, s.io), 0);
    assert.match(s.out[0] ?? '', new RegExp(`^request ${request.id} status=searching round=1`));
    assert.match(s.out[1] ?? '', /p3 pending offer=/);
  });

  it('offer refuses a photographer who is offline or stale', async () => {
    const w = createInstantWorld();
    w.customer('seed-customer-lan');
    w.clock.advance(31 * 60_000);
    const t = cli(w);
    assert.equal(await runInstantCli(['offer', '--photographer', 'p1'], LOCAL, t.io), 1);
    assert.match(t.out[0] ?? '', /not online/);
    assert.equal(w.store.requests.size, 0);
  });

  it('a domain refusal is printed with its code', async () => {
    const w = createInstantWorld();
    w.customer('c-minh', { phone: null });
    const t = cli(w);
    assert.equal(await runInstantCli(['offer', '--photographer', 'p1', '--customer', 'c-minh'], LOCAL, t.io), 1);
    assert.deepEqual(t.out, ['refused: phone_required']);
  });

  it('usage on bad arguments', async () => {
    assert.equal(parseInstantArgs(['offer']), null);
    assert.equal(parseInstantArgs(['offer', '--photographer']), null);
    assert.equal(parseInstantArgs(['offer', '--photographer', 'p1', '--colour', 'red']), null);
    assert.deepEqual(parseInstantArgs(['offer', '--photographer', 'p1', '--package', 'p30', '--genre', 'couple']), {
      kind: 'offer', photographer: 'p1', customer: 'seed-customer-lan', packageCode: 'p30', genre: 'couple',
    });
    const t = cli(createInstantWorld());
    assert.equal(await runInstantCli(['nope'], {}, t.io), 2);
    assert.deepEqual(t.out, [USAGE]);
  });
});
