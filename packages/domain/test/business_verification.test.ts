import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createVerificationWorld, MemoryIdentityVault } from './support/verification_world.js';
import { FakeTaxCodeLookup } from '../src/fake_tax_code_lookup.js';
import {
  isTaxCode,
  lookupTaxCode,
  submitBusinessVerification,
} from '../src/business_verification.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { reviewVerification } from '../src/verification_use_cases.js';
import { BUSINESS_DOC_RETENTION_DAYS, emptyVerification } from '../src/verification.js';

const refusedWith = (code: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === code;

describe('business_verification', () => {
  it('isTaxCode accepts 10, 10-3 and 12 digits', () => {
    assert.equal(isTaxCode('0312345678'), true);
    assert.equal(isTaxCode('0312345678-001'), true);
    assert.equal(isTaxCode('012345678901'), true);
    assert.equal(isTaxCode('123'), false);
    assert.equal(isTaxCode('abc1234567'), false);
  });

  it('only a verified studio may start', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    // p1 is individual
    await assert.rejects(
      lookupTaxCode(deps, 'p1', { taxCode: '0312345678' }),
      refusedWith('not_eligible'),
    );

    // s1 is studio but unverified
    await assert.rejects(
      lookupTaxCode(deps, 's1', { taxCode: '0312345678' }),
      refusedWith('not_eligible'),
    );

    // Make s1 verified
    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });

    const info = await lookupTaxCode(deps, 's1', { taxCode: '0312345678' });
    assert.equal(info.status, 'active');
  });

  it('an inactive code is not_eligible', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });

    // Codes ending in 0000 are inactive in FakeTaxCodeLookup
    await assert.rejects(
      submitBusinessVerification(deps, 's1', { taxCode: '0312340000' }),
      refusedWith('not_eligible'),
    );
  });

  it('a household code matching the owner\'s id hash is approved at once and sets businessVerified', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });

    // 12 digit tax code
    const taxCode = '012345678901';
    assert.ok(deps.vault);
    const hash = await deps.vault.hashId(taxCode);

    // Set owner identity with matching idHash
    world.store.identities.set('s1', {
      legalName: 'CHỦ STUDIO',
      dob: '1990-01-01',
      gender: null,
      idNumberEnc: 'enc',
      idHash: hash,
      method: 'vneid',
      provider: 'fake',
      providerRef: 'ref',
      verifiedAt: '2026-10-10T10:00:00.000Z',
    });
    world.store.verifications.set('s1', {
      uid: 's1',
      kind: 'studio',
      status: 'approved',
      steps: { phone: null, fee: null, identity: null, rules: null },
      identitySession: null,
      identityAttempts: { dayKey: '2026-10-10', count: 0 },
      feeAttempt: 1,
      submittedAt: null,
      decidedAt: null,
      decidedBy: null,
      rejectReason: null,
      freeResubmitsLeft: 1,
      nudgedAt: null,
      business: null,
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    });

    const res = await submitBusinessVerification(deps, 's1', { taxCode });
    assert.equal(res.after.business?.status, 'approved');
    assert.equal(res.after.business?.kind, 'household');
    assert.equal(res.after.business?.representativeMatched, true);

    const provider = await world.store.runTransaction((tx) => tx.getProvider('s1'));
    assert.equal(provider?.businessVerified, true);
  });

  it('a household code of someone else is rejected representative_mismatch', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });

    // Set owner identity with different idHash
    world.store.identities.set('s1', {
      legalName: 'CHỦ STUDIO',
      dob: '1990-01-01',
      gender: null,
      idNumberEnc: 'enc',
      idHash: 'h:different_hash',
      method: 'vneid',
      provider: 'fake',
      providerRef: 'ref',
      verifiedAt: '2026-10-10T10:00:00.000Z',
    });
    world.store.verifications.set('s1', {
      uid: 's1',
      kind: 'studio',
      status: 'approved',
      steps: { phone: null, fee: null, identity: null, rules: null },
      identitySession: null,
      identityAttempts: { dayKey: '2026-10-10', count: 0 },
      feeAttempt: 1,
      submittedAt: null,
      decidedAt: null,
      decidedBy: null,
      rejectReason: null,
      freeResubmitsLeft: 1,
      nudgedAt: null,
      business: null,
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    });

    const res = await submitBusinessVerification(deps, 's1', { taxCode: '012345678901' });
    assert.equal(res.after.business?.status, 'rejected');
    assert.equal(res.after.business?.rejectReason?.code, 'representative_mismatch');
  });

  it('a company needs a businessDocs/{uid}/ photo and becomes submitted', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });
    world.store.identities.set('s1', {
      legalName: 'CHỦ STUDIO',
      dob: '1990-01-01',
      gender: null,
      idNumberEnc: 'enc',
      idHash: 'h:some_hash',
      method: 'vneid',
      provider: 'fake',
      providerRef: 'ref',
      verifiedAt: '2026-10-10T10:00:00.000Z',
    });
    world.store.verifications.set('s1', {
      uid: 's1',
      kind: 'studio',
      status: 'approved',
      steps: { phone: null, fee: null, identity: null, rules: null },
      identitySession: null,
      identityAttempts: { dayKey: '2026-10-10', count: 0 },
      feeAttempt: 1,
      submittedAt: null,
      decidedAt: null,
      decidedBy: null,
      rejectReason: null,
      freeResubmitsLeft: 1,
      nudgedAt: null,
      business: null,
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    });

    // 10-digit company code without docPath is invalid_argument
    await assert.rejects(
      submitBusinessVerification(deps, 's1', { taxCode: '0312345678' }),
      refusedWith('invalid_argument'),
    );

    // docPath of another uid is invalid_argument
    await assert.rejects(
      submitBusinessVerification(deps, 's1', { taxCode: '0312345678', docPath: 'businessDocs/other/doc.jpg' }),
      refusedWith('invalid_argument'),
    );

    const res = await submitBusinessVerification(deps, 's1', {
      taxCode: '0312345678',
      docPath: 'businessDocs/s1/doc_001.jpg',
    });
    assert.equal(res.after.business?.status, 'submitted');
    assert.equal(res.after.business?.kind, 'company');
  });

  it('a submitted or approved business record cannot be replaced (conflict)', async () => {
    const world = createVerificationWorld();
    const deps = { ...world.deps, taxCodes: new FakeTaxCodeLookup() };
    world.store.providers.set('s1', { providerType: 'studio', onboardingComplete: true, verified: true, businessVerified: false });
    world.store.identities.set('s1', {
      legalName: 'CHỦ STUDIO', dob: '1990-01-01', gender: null, idNumberEnc: 'enc',
      idHash: await new MemoryIdentityVault().hashId('001234567890'), method: 'vneid', provider: 'fake', providerRef: 'ref',
      verifiedAt: '2026-10-10T10:00:00.000Z',
    });
    world.store.verifications.set('s1', {
      uid: 's1', kind: 'studio', status: 'approved', steps: { phone: null, fee: null, identity: null, rules: null },
      identitySession: null, identityAttempts: { dayKey: '2026-10-10', count: 0 }, feeAttempt: 1, submittedAt: null,
      decidedAt: null, decidedBy: null, rejectReason: null, freeResubmitsLeft: 1, nudgedAt: null, business: null,
      version: 1, createdAt: '2026-10-10T10:00:00.000Z', updatedAt: '2026-10-10T10:00:00.000Z',
    });
    const staff = { uid: 'staff1', isAdmin: true };

    // Submitted company: its photo must stay the one the purge will delete.
    await submitBusinessVerification(deps, 's1', { taxCode: '0312345678', docPath: 'businessDocs/s1/a.jpg' });
    await assert.rejects(
      submitBusinessVerification(deps, 's1', { taxCode: '0398765432', docPath: 'businessDocs/s1/b.jpg' }),
      refusedWith('conflict'),
    );
    assert.equal(world.store.verifications.get('s1')?.business?.docPath, 'businessDocs/s1/a.jpg');

    // Rejected: may send again.
    await reviewVerification(deps, staff, { uid: 's1', target: 'business', action: 'reject', reason: 'doc_unreadable' });
    const again = await submitBusinessVerification(deps, 's1', { taxCode: '0312345678', docPath: 'businessDocs/s1/c.jpg' });
    assert.equal(again.after.business?.status, 'submitted');

    // Approved: the verified business stays as it is (businessVerified and the record agree).
    await reviewVerification(deps, staff, { uid: 's1', target: 'business', action: 'approve' });
    await assert.rejects(submitBusinessVerification(deps, 's1', { taxCode: '001234567890' }), refusedWith('conflict'));
    assert.equal(world.store.verifications.get('s1')?.business?.taxCode, '0312345678');
    assert.equal(world.store.verifications.get('s1')?.business?.status, 'approved');
  });

  it('staff approve sets businessVerified and purgeAfter = decidedAt + 30 days', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });
    world.store.identities.set('s1', {
      legalName: 'CHỦ STUDIO',
      dob: '1990-01-01',
      gender: null,
      idNumberEnc: 'enc',
      idHash: 'h:some_hash',
      method: 'vneid',
      provider: 'fake',
      providerRef: 'ref',
      verifiedAt: '2026-10-10T10:00:00.000Z',
    });
    world.store.verifications.set('s1', {
      uid: 's1',
      kind: 'studio',
      status: 'approved',
      steps: { phone: null, fee: null, identity: null, rules: null },
      identitySession: null,
      identityAttempts: { dayKey: '2026-10-10', count: 0 },
      feeAttempt: 1,
      submittedAt: null,
      decidedAt: null,
      decidedBy: null,
      rejectReason: null,
      freeResubmitsLeft: 1,
      nudgedAt: null,
      business: null,
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    });

    await submitBusinessVerification(deps, 's1', {
      taxCode: '0312345678',
      docPath: 'businessDocs/s1/doc_001.jpg',
    });

    const approved = await reviewVerification(
      deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 's1', target: 'business', action: 'approve' },
    );

    assert.equal(approved.after.business?.status, 'approved');
    assert.ok(approved.after.business?.purgeAfter);

    const provider = await world.store.runTransaction((tx) => tx.getProvider('s1'));
    assert.equal(provider?.businessVerified, true);
  });

  it('staff reject needs a business reason', async () => {
    const world = createVerificationWorld();
    const fakeLookup = new FakeTaxCodeLookup();
    const deps = { ...world.deps, taxCodes: fakeLookup };

    world.store.providers.set('s1', {
      providerType: 'studio',
      onboardingComplete: true,
      verified: true,
      businessVerified: false,
    });
    world.store.identities.set('s1', {
      legalName: 'CHỦ STUDIO',
      dob: '1990-01-01',
      gender: null,
      idNumberEnc: 'enc',
      idHash: 'h:some_hash',
      method: 'vneid',
      provider: 'fake',
      providerRef: 'ref',
      verifiedAt: '2026-10-10T10:00:00.000Z',
    });
    world.store.verifications.set('s1', {
      uid: 's1',
      kind: 'studio',
      status: 'approved',
      steps: { phone: null, fee: null, identity: null, rules: null },
      identitySession: null,
      identityAttempts: { dayKey: '2026-10-10', count: 0 },
      feeAttempt: 1,
      submittedAt: null,
      decidedAt: null,
      decidedBy: null,
      rejectReason: null,
      freeResubmitsLeft: 1,
      nudgedAt: null,
      business: null,
      version: 1,
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    });

    await submitBusinessVerification(deps, 's1', {
      taxCode: '0312345678',
      docPath: 'businessDocs/s1/doc_001.jpg',
    });

    // Unknown reason
    await assert.rejects(
      reviewVerification(
        deps,
        { uid: 'staff1', isAdmin: true },
        { uid: 's1', target: 'business', action: 'reject', reason: 'bad_reason' },
      ),
      refusedWith('invalid_argument'),
    );

    // A note given with any reason is 5–500 characters, like the identity reject.
    for (const note of ['abc', 'x'.repeat(501)]) {
      await assert.rejects(
        reviewVerification(
          deps,
          { uid: 'staff1', isAdmin: true },
          { uid: 's1', target: 'business', action: 'reject', reason: 'doc_unreadable', note },
        ),
        refusedWith('invalid_argument'),
      );
    }
    // 'other' needs a note.
    await assert.rejects(
      reviewVerification(
        deps,
        { uid: 'staff1', isAdmin: true },
        { uid: 's1', target: 'business', action: 'reject', reason: 'other' },
      ),
      refusedWith('invalid_argument'),
    );

    const rejected = await reviewVerification(
      deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 's1', target: 'business', action: 'reject', reason: 'doc_unreadable' },
    );
    assert.equal(rejected.after.business?.status, 'rejected');
    assert.equal(rejected.after.business?.rejectReason?.code, 'doc_unreadable');
    // The registration photo of a rejected company is purged on the same 30-day clock as an approved one.
    const decided = Date.parse(rejected.after.business?.decidedAt ?? '');
    assert.equal(
      rejected.after.business?.purgeAfter,
      new Date(decided + BUSINESS_DOC_RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString(),
    );
  });

  it('FakeTaxCodeLookup: …0000 is inactive, 12 digits is household, others a company', async () => {
    const lookup = new FakeTaxCodeLookup();
    const inactive = await lookup.lookup('0312340000');
    assert.equal(inactive?.status, 'inactive');

    const household = await lookup.lookup('012345678901');
    assert.equal(household?.kind, 'household');
    assert.equal(household?.status, 'active');

    const company = await lookup.lookup('0312345678');
    assert.equal(company?.kind, 'company');
    assert.equal(company?.status, 'active');
  });

  describe('organizers (S30, Decision 3)', () => {
    const activeOrg = { status: 'active', businessVerified: false } as const;
    const suspendedOrg = { status: 'suspended', businessVerified: false } as const;

    it('an active organizer (not a provider) may submit business verification; a suspended one is conflict; a customer who is not an organizer is permission_denied as today', async () => {
      const world = createVerificationWorld();
      const deps = { ...world.deps, taxCodes: new FakeTaxCodeLookup() };
      world.store.organizers.set('org1', activeOrg);
      world.store.organizers.set('org2', suspendedOrg);

      // The lookup follows the same rule.
      assert.equal((await lookupTaxCode(deps, 'org1', { taxCode: '0312345678' })).status, 'active');
      await assert.rejects(lookupTaxCode(deps, 'org2', { taxCode: '0312345678' }), refusedWith('conflict'));
      await assert.rejects(lookupTaxCode(deps, 'c1', { taxCode: '0312345678' }), refusedWith('permission_denied'));

      // org1 has no providers/ document and no verification record yet: the record is created for the submit.
      assert.equal(world.store.verifications.has('org1'), false);
      const res = await submitBusinessVerification(deps, 'org1', {
        taxCode: '0312345678',
        docPath: 'businessDocs/org1/doc_001.jpg',
      });
      assert.equal(res.after.business?.status, 'submitted');
      assert.equal(res.after.business?.kind, 'company');
      assert.equal(res.after.business?.subject, 'organizer');
      assert.equal(world.store.verifications.get('org1')?.business?.docPath, 'businessDocs/org1/doc_001.jpg');
      // Submitted records never touch a provider document.
      assert.equal(world.store.providerFlags.size, 0);

      await assert.rejects(submitBusinessVerification(deps, 'org2', { taxCode: '0312345678', docPath: 'businessDocs/org2/d.jpg' }), refusedWith('conflict'));
      await assert.rejects(submitBusinessVerification(deps, 'c1', { taxCode: '0312345678', docPath: 'businessDocs/c1/d.jpg' }), refusedWith('permission_denied'));
      assert.equal(world.store.verifications.has('org2'), false);
      assert.equal(world.store.verifications.has('c1'), false);
      // An unverified provider who is not an organizer is refused as today.
      await assert.rejects(submitBusinessVerification(deps, 'p1', { taxCode: '0312345678', docPath: 'businessDocs/p1/d.jpg' }), refusedWith('not_eligible'));
    });

    it('an organizer sends a company for review with its registration photo, and may send again only after a rejection', async () => {
      const world = createVerificationWorld();
      const deps = { ...world.deps, taxCodes: new FakeTaxCodeLookup() };
      world.store.organizers.set('org1', activeOrg);
      await assert.rejects(submitBusinessVerification(deps, 'org1', { taxCode: '0312345678' }), refusedWith('invalid_argument'));
      await submitBusinessVerification(deps, 'org1', { taxCode: '0312345678', docPath: 'businessDocs/org1/a.jpg' });
      await assert.rejects(
        submitBusinessVerification(deps, 'org1', { taxCode: '0312345678', docPath: 'businessDocs/org1/b.jpg' }),
        refusedWith('conflict'),
      );
      await reviewVerification(deps, { uid: 'staff1', isAdmin: true }, { uid: 'org1', target: 'business', action: 'reject', reason: 'doc_unreadable' });
      const again = await submitBusinessVerification(deps, 'org1', { taxCode: '0312345678', docPath: 'businessDocs/org1/c.jpg' });
      assert.equal(again.after.business?.status, 'submitted');
      assert.equal(again.after.business?.subject, 'organizer');
    });

    it('an organizer without an identity sends a household code for staff review (photo required); with a matching identity it is approved at once', async () => {
      const world = createVerificationWorld();
      const deps = { ...world.deps, taxCodes: new FakeTaxCodeLookup() };
      world.store.organizers.set('org1', activeOrg);
      world.store.organizers.set('org2', activeOrg);
      const code = '012345678901';

      await assert.rejects(submitBusinessVerification(deps, 'org1', { taxCode: code }), refusedWith('invalid_argument'));
      const review = await submitBusinessVerification(deps, 'org1', { taxCode: code, docPath: 'businessDocs/org1/h.jpg' });
      assert.equal(review.after.business?.status, 'submitted');
      assert.equal(review.after.business?.kind, 'household');
      assert.equal(review.after.business?.representativeMatched, false);

      world.store.identities.set('org2', {
        legalName: 'CHỦ HỘ', dob: '1990-01-01', gender: null, idNumberEnc: 'enc',
        idHash: await new MemoryIdentityVault().hashId(code), method: 'vneid', provider: 'fake', providerRef: 'ref',
        verifiedAt: '2026-10-10T10:00:00.000Z',
      });
      const matched = await submitBusinessVerification(deps, 'org2', { taxCode: code });
      assert.equal(matched.after.business?.status, 'approved');
      assert.equal(matched.after.business?.subject, 'organizer');
      assert.equal(world.store.organizerFlags.get('org2')?.businessVerified, true);
      assert.equal(world.store.providerFlags.has('org2'), false);
    });

    it("approval of an organizer's record sets organizers/{uid}.businessVerified and does not write photographers/{uid}", async () => {
      const world = createVerificationWorld();
      const deps = { ...world.deps, taxCodes: new FakeTaxCodeLookup() };
      world.store.organizers.set('org1', activeOrg);
      await submitBusinessVerification(deps, 'org1', { taxCode: '0312345678', docPath: 'businessDocs/org1/a.jpg' });

      const approved = await reviewVerification(deps, { uid: 'staff1', isAdmin: true }, { uid: 'org1', target: 'business', action: 'approve' });
      assert.equal(approved.after.business?.status, 'approved');
      assert.equal(approved.after.business?.subject, 'organizer');
      assert.deepEqual(world.store.organizerFlags.get('org1'), { businessVerified: true });
      assert.equal(world.store.providerFlags.has('org1'), false);
      const view = await world.store.runTransaction((tx) => tx.getOrganizer('org1'));
      assert.equal(view?.businessVerified, true);
    });

    it("a studio's approval behaves as today: it patches photographers/{uid} and no organizer", async () => {
      const world = createVerificationWorld();
      const deps = { ...world.deps, taxCodes: new FakeTaxCodeLookup() };
      world.store.providers.set('s1', { providerType: 'studio', onboardingComplete: true, verified: true, businessVerified: false });
      world.store.identities.set('s1', {
        legalName: 'CHỦ STUDIO', dob: '1990-01-01', gender: null, idNumberEnc: 'enc', idHash: 'h:x', method: 'vneid',
        provider: 'fake', providerRef: 'ref', verifiedAt: '2026-10-10T10:00:00.000Z',
      });
      world.store.organizers.set('s1', activeOrg); // a studio that is also an organizer stays a studio submission
      const sent = await submitBusinessVerification(deps, 's1', { taxCode: '0312345678', docPath: 'businessDocs/s1/a.jpg' }).catch((e: unknown) => e);
      // No verification record yet: a provider needs its S21 record first, as today.
      assert.ok(sent instanceof DomainError && sent.code === 'not_eligible');
      world.store.verifications.set('s1', emptyVerification('s1', 'studio', world.clock.now()));
      const res = await submitBusinessVerification(deps, 's1', { taxCode: '0312345678', docPath: 'businessDocs/s1/a.jpg' });
      assert.equal(res.after.business?.subject, 'studio');
      await reviewVerification(deps, { uid: 'staff1', isAdmin: true }, { uid: 's1', target: 'business', action: 'approve' });
      assert.equal(world.store.providerFlags.get('s1')?.businessVerified, true);
      assert.equal(world.store.organizerFlags.size, 0);
    });
  });
});
