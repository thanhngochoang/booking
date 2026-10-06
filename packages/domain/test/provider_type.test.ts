import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { chosenTypeOf, providerTypeOf } from '../src/provider_type.js';

describe('provider type', () => {
  it('missing or unknown type reads as individual', () => {
    assert.equal(providerTypeOf(undefined), 'individual');
    assert.equal(providerTypeOf(null), 'individual');
    assert.equal(providerTypeOf('agency'), 'individual');
    assert.equal(providerTypeOf(3), 'individual');
    assert.equal(providerTypeOf('studio'), 'studio');
    assert.equal(providerTypeOf('artist'), 'artist');
  });

  it('artist is chosen as individual', () => {
    assert.equal(chosenTypeOf('artist'), 'individual');
    assert.equal(chosenTypeOf('individual'), 'individual');
    assert.equal(chosenTypeOf('studio'), 'studio');
  });
});
