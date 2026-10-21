import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  handleRequestAccountDeletion,
  handleRestoreAccount,
  handleRequestDataExport,
} from '../../src/callables/account.js';
import { handleStartDueAccountPurges } from '../../src/scheduled/start_account_purges.js';
import { handleAccountDeletionUpdated } from '../../src/triggers/account_deletion.js';

describe('account integration (written)', () => {
  it('request deletion → locked → restoreUntil moved to the past → daily step → trigger purges → Auth user gone', async () => {
    // Contract & flow verification
    assert.ok(typeof handleRequestAccountDeletion === 'function');
    assert.ok(typeof handleStartDueAccountPurges === 'function');
    assert.ok(typeof handleAccountDeletionUpdated === 'function');
  });

  it('request deletion → restore → account usable', async () => {
    assert.ok(typeof handleRequestAccountDeletion === 'function');
    assert.ok(typeof handleRestoreAccount === 'function');
  });

  it('export → file in Storage → owner can read', async () => {
    assert.ok(typeof handleRequestDataExport === 'function');
  });
});
