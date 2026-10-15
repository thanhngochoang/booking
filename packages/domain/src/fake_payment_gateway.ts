/**
 * Fake payment gateway reference adapter for testing and dev emulators.
 */

import type { PayerBankAccount, PaymentGateway, PaymentInstructions, TransferNotification } from './booking_ports.js';
import type { PaymentProvider } from './booking.js';
import type { PaymentMethod, RefundMethod } from './escrow.js';
import { buildVietQrPayload } from './vietqr.js';

/** Test values only (#129 Decision 15): a BIDV collection account that receives no real money. */
export const FAKE_COLLECTION_ACCOUNT = {
  bin: '970418',
  accountNumber: '96247000003812',
  bankName: 'BIDV',
  accountMasked: '9624 •••• 3812',
  bankAppsUrl: 'https://fake-pay.local/bank-apps',
} as const;

export type FakeCreatePaymentCall = Parameters<PaymentGateway['createPayment']>[0];

export class FakePaymentGateway implements PaymentGateway {
  readonly provider = 'fake' as const;
  /** Every `createPayment` call, in order. */
  readonly createPaymentCalls: FakeCreatePaymentCall[] = [];
  /** Every `queryTransfers` call, by payment id. */
  readonly queryTransfersCalls: string[] = [];
  private readonly transfers = new Map<string, TransferNotification[]>();
  readonly paidPayments = new Set<string>();
  /** Refunds the fake has paid back, by refund id (a repeated id is the same refund, never a second one). */
  readonly issuedRefunds = new Map<string, number>();
  /** Every `issueRefund` call, by refund id (repeats included). */
  readonly refundCalls: string[] = [];
  /** Requests issued to the fake gateway, storing method and destination. */
  readonly refundRequests = new Map<string, { method: RefundMethod; destination?: PayerBankAccount }>();
  /** Refund IDs that should answer { success: true, pending: true }. */
  readonly refundPendingIds = new Set<string>();
  refundFailureId?: string;
  /** The next this-many `issueRefund` calls throw (a provider outage), after being recorded in `refundCalls`. */
  refundThrowCount = 0;
  /** `queryTransfers` throws for these payment ids. */
  readonly queryThrowIds = new Set<string>();

  async createDepositIntent(params: {
    readonly paymentId: string;
    readonly bookingId: string;
    readonly amount: number;
    readonly provider: PaymentProvider;
    readonly returnUrl?: string;
  }): Promise<{ readonly payUrl: string; readonly providerRef?: string }> {
    return {
      payUrl: `https://fake-pay.local/checkout?paymentId=${params.paymentId}&amount=${params.amount}`,
      providerRef: `fake_ref_${params.paymentId}`,
    };
  }

  async issueRefund(params: {
    readonly paymentId: string;
    readonly refundId: string;
    readonly amount: number;
    readonly provider: PaymentProvider;
    readonly providerRef?: string;
    readonly method?: RefundMethod;
    readonly destination?: PayerBankAccount;
  }): Promise<{ readonly success: boolean; readonly providerRef?: string; readonly pending?: boolean; readonly error?: string }> {
    this.refundCalls.push(params.refundId);
    if (params.method) {
      this.refundRequests.set(params.refundId, {
        method: params.method,
        destination: params.destination,
      });
    }
    if (this.refundThrowCount > 0) {
      this.refundThrowCount -= 1;
      throw new Error('simulated_gateway_outage');
    }
    if (this.refundFailureId === params.refundId) {
      return { success: false, error: 'fake_refund_failed' };
    }
    if (!this.issuedRefunds.has(params.refundId)) this.issuedRefunds.set(params.refundId, params.amount);
    const providerRef = `fake_refund_${params.refundId}`;
    if (this.refundPendingIds.has(params.refundId)) {
      return {
        success: true,
        pending: true,
        providerRef: `fake_pending_${params.refundId}`,
      };
    }
    return {
      success: true,
      providerRef,
    };
  }

  async checkPaymentStatus(params: {
    readonly paymentId: string;
    readonly provider: PaymentProvider;
    readonly providerRef?: string;
  }): Promise<{ readonly paid: boolean; readonly providerRef?: string }> {
    return {
      paid: this.paidPayments.has(params.paymentId),
      providerRef: `fake_ref_${params.paymentId}`,
    };
  }

  async createPayment(params: {
    readonly paymentId: string;
    readonly bookingId: string;
    readonly amount: number;
    readonly method: PaymentMethod;
    readonly transferCode: string;
    readonly expiresAt: string;
    readonly idempotencyKey: string;
  }): Promise<PaymentInstructions> {
    this.createPaymentCalls.push({ ...params });
    const providerRef = `fake_ref_${params.paymentId}`;
    if (params.method === 'bank_qr') {
      const a = FAKE_COLLECTION_ACCOUNT;
      return {
        providerRef,
        qrPayload: buildVietQrPayload({
          bin: a.bin,
          accountNumber: a.accountNumber,
          amount: params.amount,
          content: params.transferCode,
        }),
        bankName: a.bankName,
        accountMasked: a.accountMasked,
        bankAppsUrl: a.bankAppsUrl,
      };
    }
    return { providerRef, payUrl: `https://fake-pay.local/${params.method}?paymentId=${params.paymentId}` };
  }

  async queryTransfers(params: {
    readonly paymentId: string;
    readonly transferCode: string;
    readonly providerRef?: string;
  }): Promise<readonly TransferNotification[]> {
    this.queryTransfersCalls.push(params.paymentId);
    if (this.queryThrowIds.has(params.paymentId)) throw new Error('simulated_gateway_outage');
    return [...(this.transfers.get(params.paymentId) ?? [])];
  }

  /** Makes `queryTransfers` report `n` for this payment from now on (a transfer the provider received). */
  pushTransfer(paymentId: string, n: TransferNotification): void {
    this.transfers.set(paymentId, [...(this.transfers.get(paymentId) ?? []), n]);
  }

  markPaid(paymentId: string): void {
    this.paidPayments.add(paymentId);
  }
}
