import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  OTP_MAX_ATTEMPTS,
  OTP_MAX_SENDS_PER_DAY,
  OTP_RESEND_SECONDS,
  OTP_TTL_SECONDS,
  checkOtp,
  otpCodeFrom,
  type OtpChallenge,
} from '../src/payout_otp.js';

const NOW = new Date('2026-10-10T10:00:00.000Z');

const challenge = (over: Partial<OtpChallenge> = {}): OtpChallenge => ({
  uid: 'p1',
  purpose: 'payout_account',
  codeHash: 'code-hash',
  salt: 'salt',
  targetHash: 'target-hash',
  expiresAt: new Date(NOW.getTime() + OTP_TTL_SECONDS * 1000).toISOString(),
  attempts: 0,
  sentAt: NOW.toISOString(),
  sendDay: '2026-10-10',
  sendsToday: 1,
  consumedAt: null,
  ...over,
});

const right = { codeHash: 'code-hash', targetHash: 'target-hash' };

describe('payout OTP rules', () => {
  it('constants: 5 minutes, 5 tries, 60 s resend, 5 sends a day', () => {
    assert.deepEqual([OTP_TTL_SECONDS, OTP_MAX_ATTEMPTS, OTP_RESEND_SECONDS, OTP_MAX_SENDS_PER_DAY], [300, 5, 60, 5]);
  });

  it('otpCodeFrom gives 6 digits, zero padded', () => {
    assert.equal(otpCodeFrom(new Uint8Array([0, 0, 0, 7])), '000007');
    assert.equal(otpCodeFrom(new Uint8Array([0xff, 0xff, 0xff, 0xff])), '967295'); // 4294967295 % 1e6
    assert.equal(otpCodeFrom(new Uint8Array([0x00, 0x0f, 0x42, 0x40])), '000000'); // 1,000,000
    assert.equal(otpCodeFrom(new Uint8Array([0x80, 0, 0, 1, 9, 9])), '483649'); // 2147483649, extra bytes ignored
    for (let i = 0; i < 50; i += 1) {
      assert.match(otpCodeFrom(new Uint8Array([i, i * 3, i * 7, i * 11])), /^[0-9]{6}$/);
    }
    assert.throws(() => otpCodeFrom(new Uint8Array([1, 2, 3])));
  });

  it('checkOtp: missing → required; consumed → required; other target → required', () => {
    assert.equal(checkOtp(null, right, NOW), 'required');
    assert.equal(checkOtp(challenge({ consumedAt: NOW.toISOString() }), right, NOW), 'required');
    assert.equal(checkOtp(challenge(), { ...right, targetHash: 'other' }, NOW), 'required');
  });

  it('checkOtp: expired → expired; attempts 5 → too_many; wrong hash → wrong; right → ok', () => {
    const expiry = new Date(NOW.getTime() + OTP_TTL_SECONDS * 1000);
    assert.equal(checkOtp(challenge(), right, expiry), 'expired');
    assert.equal(checkOtp(challenge({ expiresAt: 'garbage' }), right, NOW), 'expired');
    assert.equal(checkOtp(challenge({ attempts: OTP_MAX_ATTEMPTS }), right, NOW), 'too_many');
    assert.equal(checkOtp(challenge({ attempts: OTP_MAX_ATTEMPTS - 1 }), { ...right, codeHash: 'nope' }, NOW), 'wrong');
    assert.equal(checkOtp(challenge({ attempts: OTP_MAX_ATTEMPTS - 1 }), right, NOW), 'ok');
    assert.equal(checkOtp(challenge(), right, new Date(expiry.getTime() - 1)), 'ok');
  });
});
