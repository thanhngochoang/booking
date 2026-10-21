import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildExportDocument,
  exportAllowed,
  requestDataExport,
  EXPORT_SCHEMA_VERSION,
  EXPORT_TTL_DAYS,
  EXPORT_REDACTED_KEYS,
  type DataExportDeps,
  type ExportParts,
} from '../src/data_export.js';
import { DomainError } from '../src/errors.js';

describe('data_export', () => {
  it('buildExportDocument removes accountNumberEnc, payer, candidate, providerRef, token at any depth', () => {
    const parts: ExportParts = {
      profile: {
        name: 'Nguyen Van A',
        email: 'a@example.com',
        token: 'secret-fcm-token',
        nested: {
          accountNumberEnc: 'enc-1234',
          providerRef: 'ref-999',
          payer: { name: 'Payer 1' },
          candidate: { name: 'Candidate 1' },
          raw: { data: 123 },
          idHash: 'hash-abc',
          instructions: 'instructions text',
          safeField: 'keep this',
        },
      },
      bookings: [
        {
          id: 'b1',
          token: 'token-b1',
          amount: 500000,
        },
      ],
    };

    const now = new Date('2026-10-21T10:00:00Z');
    const doc = buildExportDocument(parts, now);

    assert.equal(doc.schemaVersion, EXPORT_SCHEMA_VERSION);
    assert.equal(doc.generatedAt, now.toISOString());

    const profile = doc.profile as Record<string, unknown>;
    assert.equal(profile.name, 'Nguyen Van A');
    assert.equal(profile.token, undefined);
    assert.equal((profile.nested as Record<string, unknown>).safeField, 'keep this');
    for (const key of EXPORT_REDACTED_KEYS) {
      assert.equal((profile.nested as Record<string, unknown>)[key], undefined);
    }

    const bookings = doc.bookings as Array<Record<string, unknown>>;
    assert.ok(bookings[0] !== undefined);
    assert.equal(bookings[0].id, 'b1');
    assert.equal(bookings[0].token, undefined);
    assert.equal(bookings[0].amount, 500000);
  });

  it('adds schemaVersion and generatedAt', () => {
    const now = new Date('2026-10-21T10:00:00Z');
    const doc = buildExportDocument({}, now);
    assert.equal(doc.schemaVersion, 1);
    assert.equal(doc.generatedAt, '2026-10-21T10:00:00.000Z');
  });

  it('exportAllowed false within 24 h', () => {
    const now = new Date('2026-10-21T10:00:00Z');
    const last23h = new Date(now.getTime() - 23 * 60 * 60 * 1000);
    const last25h = new Date(now.getTime() - 25 * 60 * 60 * 1000);

    assert.equal(exportAllowed(null, now), true);
    assert.equal(exportAllowed(last23h, now), false);
    assert.equal(exportAllowed(last25h, now), true);
  });

  it('requestDataExport writes, records expiresAt +7 days', async () => {
    const now = new Date('2026-10-21T10:00:00Z');
    let writtenPath = '';
    let writtenJson = '';
    const records: Array<{ path: string; sizeBytes: number; createdAt: Date; expiresAt: Date }> = [];

    const deps: DataExportDeps = {
      gather: async () => ({ profile: { name: 'Test' } }),
      last: async () => null,
      pending: async () => false,
      write: async (uid, exportId, json) => {
        writtenPath = `exports/${uid}/${exportId}.json`;
        writtenJson = json;
        return { path: writtenPath, sizeBytes: json.length };
      },
      record: async (uid, rec) => {
        records.push(rec);
      },
      clock: { now: () => now },
      ids: { newId: () => 'exp123' },
    };

    const res = await requestDataExport(deps, { uid: 'u1' }, {});
    assert.equal(res.path, 'exports/u1/exp123.json');
    assert.equal(res.sizeBytes, writtenJson.length);

    const expectedExpiry = new Date(now.getTime() + EXPORT_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();
    assert.equal(res.expiresAt, expectedExpiry);
    assert.equal(records.length, 1);
    assert.ok(records[0] !== undefined);
    assert.equal(records[0].expiresAt.toISOString(), expectedExpiry);
    assert.equal(records[0].path, res.path);
  });

  it('a second export within 24 h → limit_exceeded', async () => {
    const now = new Date('2026-10-21T10:00:00Z');
    const lastExport = new Date(now.getTime() - 2 * 60 * 60 * 1000); // 2 hours ago

    const deps: DataExportDeps = {
      gather: async () => ({}),
      last: async () => lastExport,
      pending: async () => false,
      write: async () => ({ path: '', sizeBytes: 0 }),
      record: async () => {},
      clock: { now: () => now },
      ids: { newId: () => 'id1' },
    };

    await assert.rejects(
      async () => requestDataExport(deps, { uid: 'u1' }, {}),
      (err: DomainError) => {
        assert.equal(err.code, 'limit_exceeded');
        return true;
      },
    );
  });

  it('an export while deletion is pending → not_eligible', async () => {
    // Decision 11
    const deps: DataExportDeps = {
      gather: async () => ({}),
      last: async () => null,
      pending: async () => true, // deletion pending
      write: async () => ({ path: '', sizeBytes: 0 }),
      record: async () => {},
      clock: { now: () => new Date() },
      ids: { newId: () => 'id1' },
    };

    await assert.rejects(
      async () => requestDataExport(deps, { uid: 'u1' }, {}),
      (err: DomainError) => {
        assert.equal(err.code, 'not_eligible');
        return true;
      },
    );
  });
});
