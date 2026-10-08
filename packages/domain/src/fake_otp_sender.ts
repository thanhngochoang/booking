/** Reference OTP sender for tests and the emulator: keeps every code it was asked to send. */

import type { OtpSender } from './account_lookup.js';

export class FakeOtpSender implements OtpSender {
  readonly sent: { phone: string; code: string }[] = [];

  async send(r: { phone: string; code: string; purpose: 'payout_account' }): Promise<void> {
    this.sent.push({ phone: r.phone, code: r.code });
  }
}
