import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createVerificationWorld } from './support/verification_world.js';
import { FakeIdentityVerifier, fakeIdNumberOf } from '../src/fake_identity_verifier.js';
import {
  completeIdentityVerification,
  startIdentityVerification,
} from '../src/identity_verification.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { confirmPhoneVerified, reviewVerification, submitVerification } from '../src/verification_use_cases.js';
import { acceptVerificationRules } from '../src/verification_use_cases.js';
import { PROVIDER_RULES_VERSION } from '../src/verification.js';
import { startVerificationFee } from '../src/verification_fee.js';

const refusedWith = (code: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === code;

describe('identity_verification', () => {
  it('start needs no fee while feeRequired is false', async () => {
    const world = createVerificationWorld({ feeRequired: false });
    const fakeVerifier = new FakeIdentityVerifier(async () => null, world.ids);
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const res = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    assert.ok(res.sessionId);
  });

  it('start needs the fee paid', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    let starts = 0;
    const fakeVerifier = new FakeIdentityVerifier(async () => null, world.ids);
    const counting = { start: async (uid: string, m: 'vneid' | 'nfc') => { starts++; return fakeVerifier.start(uid, m); }, result: fakeVerifier.result.bind(fakeVerifier) };
    const deps = { ...world.deps, identity: counting };

    await confirmPhoneVerified(deps, 'p1');
    await assert.rejects(startIdentityVerification(deps, 'p1', { method: 'vneid' }), refusedWith('not_eligible'));
    // Refused before the vendor: a session costs money.
    assert.equal(starts, 0);

    const inst = await startVerificationFee(deps, 'p1', { method: 'bank_qr' });
    await world.payFee(inst.paymentId);
    const res = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    assert.ok(res.sessionId);
    assert.equal(starts, 1);
  });

  it('a grandfathered record rejected for identity_mismatch can start identity without paying', async () => {
    // Submitted and rejected while the fee was off (#135), then the fee turned on (#203).
    const free = createVerificationWorld({ feeRequired: false });
    let starts = 0;
    const fakeVerifier = new FakeIdentityVerifier(async () => null, free.ids);
    const counting = { start: async (uid: string, m: 'vneid' | 'nfc') => { starts++; return fakeVerifier.start(uid, m); }, result: fakeVerifier.result.bind(fakeVerifier) };
    const freeDeps = { ...free.deps, identity: counting };
    await confirmPhoneVerified(freeDeps, 'p1');
    const first = await startIdentityVerification(freeDeps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(freeDeps, 'p1', { sessionId: first.sessionId });
    await acceptVerificationRules(freeDeps, 'p1', { version: PROVIDER_RULES_VERSION });
    await submitVerification(freeDeps, 'p1');
    await reviewVerification(freeDeps, { uid: 'staff1', isAdmin: true }, { uid: 'p1', action: 'reject', reason: 'identity_mismatch' });

    const deps = { ...freeDeps, feeRequired: true };
    const rec = free.store.verifications.get('p1');
    assert.ok(rec);
    assert.equal(rec.steps.fee, null);
    assert.equal(rec.steps.identity, null);
    assert.equal(rec.freeResubmitsLeft, 1);

    const again = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    assert.ok(again.sessionId);
    assert.equal(starts, 2);
    const done = await completeIdentityVerification(deps, 'p1', { sessionId: again.sessionId });
    assert.equal(done.result, 'passed');
    assert.equal(free.store.payments.size, 0);
  });

  it('start after identity passed is conflict', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(async () => null, world.ids);
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId });

    await assert.rejects(
      startIdentityVerification(deps, 'p1', { method: 'vneid' }),
      refusedWith('conflict'),
    );
  });

  it('a fourth start in one VN day is rate_limited, the next day works', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(async () => null, world.ids);
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');

    // 1st start
    await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    // 2nd start
    await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    // 3rd start
    await startIdentityVerification(deps, 'p1', { method: 'vneid' });

    // 4th start is rate limited
    await assert.rejects(
      startIdentityVerification(deps, 'p1', { method: 'vneid' }),
      refusedWith('rate_limited'),
    );

    // Next day
    world.clock.advanceHours(25);
    const nextStart = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    assert.ok(nextStart.sessionId);
  });

  it('start without a verifier is not_eligible', async () => {
    const world = createVerificationWorld();
    // deps.identity is null
    await assert.rejects(
      startIdentityVerification(world.deps, 'p1', { method: 'vneid' }),
      refusedWith('not_eligible'),
    );
  });

  it('complete with an unknown or used session is not_found', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(async () => null, world.ids);
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });

    await assert.rejects(
      completeIdentityVerification(deps, 'p1', { sessionId: 'unknown_session' }),
      refusedWith('not_found'),
    );

    await completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId });

    // Reusing the same session is not found
    await assert.rejects(
      completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId }),
      refusedWith('not_found'),
    );
  });

  it('a passing result stores the encrypted id, the hash guard and the masked name', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ legalName: 'NGUYỄN MINH TRÍ', idNumber: '012345678901' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    const res = await completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId });

    assert.equal(res.result, 'passed');
    assert.equal(res.maskedName, 'NGUYỄN M** T**');

    const identity = await world.store.runTransaction((tx) => tx.getIdentity('p1'));
    assert.ok(identity);
    assert.equal(identity.legalName, 'NGUYỄN MINH TRÍ');
    assert.equal(identity.idNumberEnc, 'enc:012345678901');
    assert.equal(identity.idHash, 'h:109876543210');

    const hashOwner = await world.store.runTransaction((tx) => tx.identityOwner('h:109876543210'));
    assert.equal(hashOwner, 'p1');
  });

  it('the owner doc never stores the id number or the full name', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ legalName: 'NGUYỄN MINH TRÍ', idNumber: '012345678901' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId });

    const rec = await world.store.runTransaction((tx) => tx.getVerification('p1'));
    assert.ok(rec);
    assert.equal(rec.steps.identity?.maskedName, 'NGUYỄN M** T**');
    assert.equal((rec.steps.identity as unknown as Record<string, unknown>).idNumber, undefined);
    assert.equal((rec.steps.identity as unknown as Record<string, unknown>).legalName, undefined);
  });

  it('the stored identity\'s legalName is what VerifiedNameReader reads', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ legalName: 'TRẦN VĂN AN' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId });

    const idRec = await world.store.runTransaction((tx) => tx.getIdentity('p1'));
    assert.equal(idRec?.legalName, 'TRẦN VĂN AN');
  });

  it('under 18 is underage and counts an attempt', async () => {
    const world = createVerificationWorld();
    // 16 years old in 2026
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ dob: '2010-01-01' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });

    await assert.rejects(
      completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId }),
      refusedWith('underage'),
    );

    const rec = await world.store.runTransaction((tx) => tx.getVerification('p1'));
    assert.equal(rec?.steps.identity?.result, 'failed');
    assert.equal(rec?.steps.identity?.failure, 'underage');
    assert.equal(rec?.identityAttempts.count, 1);
  });

  it('an id owned by another uid is identity_in_use, counts an attempt and audits the other uid', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ idNumber: '012345678901' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    // s1 verifies first with this id
    await confirmPhoneVerified(deps, 's1');
    const s1Start = await startIdentityVerification(deps, 's1', { method: 'vneid' });
    await completeIdentityVerification(deps, 's1', { sessionId: s1Start.sessionId });

    // p1 tries with the same idNumber
    await confirmPhoneVerified(deps, 'p1');
    const p1Start = await startIdentityVerification(deps, 'p1', { method: 'vneid' });

    await assert.rejects(
      completeIdentityVerification(deps, 'p1', { sessionId: p1Start.sessionId }),
      refusedWith('identity_in_use'),
    );

    const audit = world.store.audits.find((a) => a.uid === 'p1' && a.action === 'duplicate');
    assert.ok(audit);
    assert.equal(audit.otherUid, 's1');
  });

  it('the same uid verifying again keeps its own hash', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ idNumber: '012345678901' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const s1 = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(deps, 'p1', { sessionId: s1.sessionId });

    // Reset identity step (e.g. staff rejected with identity_mismatch)
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: { ...rec.steps, identity: null },
      });
    });

    // p1 verifies again with the same id
    const s2 = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    const res = await completeIdentityVerification(deps, 'p1', { sessionId: s2.sessionId });
    assert.equal(res.result, 'passed');
  });

  it('the hash guard is created in the same transaction as the identity', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ idNumber: '012345678901' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const startRes = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(deps, 'p1', { sessionId: startRes.sessionId });

    assert.ok(deps.vault);
    const hash = await deps.vault.hashId('012345678901');
    assert.equal(world.store.identityHashes.get(hash), 'p1');
    assert.ok(world.store.identities.get('p1'));
  });

  it('identity_mismatch reopened by staff can pass again', async () => {
    const world = createVerificationWorld();
    const fakeVerifier = new FakeIdentityVerifier(
      async () => ({ legalName: 'NGUYEN A' }),
      world.ids,
    );
    const deps = { ...world.deps, identity: fakeVerifier };

    await confirmPhoneVerified(deps, 'p1');
    const s1 = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
    await completeIdentityVerification(deps, 'p1', { sessionId: s1.sessionId });
    await acceptVerificationRules(deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await submitVerification(deps, 'p1');

    await reviewVerification(
      deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'identity_mismatch' },
    );

    // Reopened: identity is cleared, can start and complete again
    const s2 = await startIdentityVerification(deps, 'p1', { method: 'nfc' });
    const pass = await completeIdentityVerification(deps, 'p1', { sessionId: s2.sessionId });
    assert.equal(pass.result, 'passed');
  });

  it('FakeIdentityVerifier uses the override when present', async () => {
    const ids = createVerificationWorld().ids;
    const verifier = new FakeIdentityVerifier(
      async (uid) => uid === 'p1' ? { legalName: 'CUSTOM NAME', idNumber: '099999999999' } : null,
      ids,
    );

    const res = await verifier.result('p1', 'session_1');
    assert.equal(res.legalName, 'CUSTOM NAME');
    assert.equal(res.idNumber, '099999999999');

    const resDefault = await verifier.result('other', 'session_2');
    assert.equal(resDefault.legalName, 'NGUOI DUNG THU');
  });

  it('fakeIdNumberOf is 12 digits starting with 0 and stable per uid', () => {
    const id1 = fakeIdNumberOf('p1');
    const id2 = fakeIdNumberOf('p1');
    const id3 = fakeIdNumberOf('other');

    assert.equal(id1.length, 12);
    assert.equal(id1.startsWith('0'), true);
    assert.equal(id1, id2);
    assert.notEqual(id1, id3);
  });

  describe('the vendor is not called when the request is refused', () => {
    /** Wraps the fake verifier and counts calls to `start` and `result`. */
    class CountingVerifier extends FakeIdentityVerifier {
      starts = 0;
      results = 0;
      override async start(uid: string, method: 'vneid' | 'nfc') {
        this.starts++;
        return super.start(uid, method);
      }
      override async result(uid: string, sessionId: string) {
        this.results++;
        return super.result(uid, sessionId);
      }
    }

    it('start after identity passed is conflict without calling start', async () => {
      const world = createVerificationWorld();
      const verifier = new CountingVerifier(async () => null, world.ids);
      const deps = { ...world.deps, identity: verifier };

      await confirmPhoneVerified(deps, 'p1');
      const s = await startIdentityVerification(deps, 'p1', { method: 'vneid' });
      await completeIdentityVerification(deps, 'p1', { sessionId: s.sessionId });
      assert.equal(verifier.starts, 1);

      await assert.rejects(
        startIdentityVerification(deps, 'p1', { method: 'vneid' }),
        refusedWith('conflict'),
      );
      assert.equal(verifier.starts, 1);
    });

    it('a rate_limited start does not call start', async () => {
      const world = createVerificationWorld();
      const verifier = new CountingVerifier(async () => null, world.ids);
      const deps = { ...world.deps, identity: verifier };

      await confirmPhoneVerified(deps, 'p1');
      for (let i = 0; i < 3; i++) {
        await startIdentityVerification(deps, 'p1', { method: 'vneid' });
      }
      assert.equal(verifier.starts, 3);

      await assert.rejects(
        startIdentityVerification(deps, 'p1', { method: 'nfc' }),
        refusedWith('rate_limited'),
      );
      assert.equal(verifier.starts, 3);
    });

    it('complete with an unknown session is not_found without calling result', async () => {
      const world = createVerificationWorld();
      const verifier = new CountingVerifier(async () => null, world.ids);
      const deps = { ...world.deps, identity: verifier };

      await confirmPhoneVerified(deps, 'p1');
      await startIdentityVerification(deps, 'p1', { method: 'vneid' });

      await assert.rejects(
        completeIdentityVerification(deps, 'p1', { sessionId: 'unknown_session' }),
        refusedWith('not_found'),
      );
      assert.equal(verifier.results, 0);
    });

    it('complete for another uid\'s session is not_found without calling result', async () => {
      const world = createVerificationWorld();
      const verifier = new CountingVerifier(async () => null, world.ids);
      const deps = { ...world.deps, identity: verifier };

      await confirmPhoneVerified(deps, 'p1');
      const s = await startIdentityVerification(deps, 'p1', { method: 'vneid' });

      await assert.rejects(
        completeIdentityVerification(deps, 's1', { sessionId: s.sessionId }),
        refusedWith('not_found'),
      );
      assert.equal(verifier.results, 0);
    });
  });
});
