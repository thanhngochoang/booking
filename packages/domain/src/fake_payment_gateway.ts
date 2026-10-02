/**
 * Fake payment gateway reference adapter for testing and dev emulators.
 */

import type { PaymentGateway } from './booking_ports.js';
import type { PaymentProvider } from './booking.js';

export class FakePaymentGateway implements PaymentGateway {
  readonly paidPayments = new Set<string>();
  refundFailureId?: string;

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
  }): Promise<{ readonly success: boolean; readonly providerRef?: string; readonly error?: string }> {
    if (this.refundFailureId === params.refundId) {
      return { success: false, error: 'simulated_refund_failure' };
    }
    return {
      success: true,
      providerRef: `fake_refund_${params.refundId}`,
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

  markPaid(paymentId: string): void {
    this.paidPayments.add(paymentId);
  }
}
