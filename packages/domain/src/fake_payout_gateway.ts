/** Reference payout gateway for tests and the dev emulator; idempotent by `payoutId`. */

import type { PayoutGateway } from './payout_ports.js';

type Outcome = { status: 'paid' | 'failed'; reference?: string; failureReason?: string };

export class FakePayoutGateway implements PayoutGateway {
  /** Every call, by payout id (a retry shows up twice). */
  readonly calls: string[] = [];
  /** The outcome decided for each payout id; a retry returns the same one. */
  readonly outcomes = new Map<string, Outcome>();

  async transfer(r: {
    payoutId: string;
    amount: number;
    bankCode: string;
    accountNumber: string;
    holderName: string;
  }): Promise<Outcome> {
    this.calls.push(r.payoutId);
    const known = this.outcomes.get(r.payoutId);
    if (known !== undefined) return { ...known };
    const outcome: Outcome = r.accountNumber.endsWith('0000')
      ? { status: 'failed', failureReason: 'account_rejected' }
      : { status: 'paid', reference: `FAKE-${r.payoutId}` };
    this.outcomes.set(r.payoutId, outcome);
    return { ...outcome };
  }
}
