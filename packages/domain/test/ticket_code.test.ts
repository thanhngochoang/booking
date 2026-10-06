import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TICKET_ALPHABET, isTicketCode, ticketCodeCandidates } from '../src/ticket_code.js';
import { makeRandom } from './support/event_world.js';

test('codes match VE-XXXX-MMDD without 0 O 1 I', () => {
  const codes = ticketCodeCandidates(new Date('2026-10-04T02:00:00.000Z'), makeRandom(), 50);
  assert.ok(codes.length > 0);
  for (const c of codes) {
    assert.ok(isTicketCode(c), c);
    assert.doesNotMatch(c.slice(3, 7), /[01OI]/);
  }
  assert.equal(TICKET_ALPHABET.length, 32);
  assert.equal(isTicketCode('VE-AB0D-1004'), false);
  assert.equal(isTicketCode('VE-ABCD-104'), false);
});

test('MMDD is the VN event day', () => {
  // 20:00 UTC on 3 Oct is 03:00 on 4 Oct in Vietnam
  const [code] = ticketCodeCandidates(new Date('2026-10-03T20:00:00.000Z'), makeRandom());
  assert.ok(code?.endsWith('-1004'), code);
});

test('candidates are distinct', () => {
  const codes = ticketCodeCandidates(new Date('2026-10-04T02:00:00.000Z'), makeRandom(), 5);
  assert.equal(codes.length, 5);
  assert.equal(new Set(codes).size, 5);
  // a source stuck on one value cannot loop forever
  assert.equal(ticketCodeCandidates(new Date(), () => new Uint8Array(4), 5).length, 1);
});
