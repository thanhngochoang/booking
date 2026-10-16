import type { Payment, TransferRecord } from './index.js';
import type { PaymentLookup } from './payment_settlement.js';

export interface PaymentSource {
  readonly payments: ReadonlyMap<string, Payment>;
  readonly transferRecords: Map<string, TransferRecord>;
}

export class MemoryPaymentLookup implements PaymentLookup {
  constructor(private readonly sources: readonly PaymentSource[]) {}

  async getPayment(id: string): Promise<Payment | null> {
    for (const source of this.sources) {
      const p = source.payments.get(id);
      if (p) return p;
    }
    return null;
  }

  async findPaymentsByTransferCode(code: string): Promise<readonly Payment[]> {
    const results: Payment[] = [];
    for (const source of this.sources) {
      for (const p of source.payments.values()) {
        if (p.transferCode === code) {
          results.push(p);
        }
      }
    }
    return results;
  }

  async getTransferRecord(id: string): Promise<TransferRecord | null> {
    for (const source of this.sources) {
      const rec = source.transferRecords.get(id);
      if (rec) return rec;
    }
    return null;
  }

  async saveUnmatchedTransfer(record: TransferRecord): Promise<void> {
    const primary = this.sources[0];
    if (!primary) return;
    if (!primary.transferRecords.has(record.id)) {
      primary.transferRecords.set(record.id, record);
    }
  }

  async findPaymentsToReconcile(createdBefore: Date, limit?: number): Promise<readonly Payment[]> {
    const results: Payment[] = [];
    const cutoff = createdBefore.getTime();
    for (const source of this.sources) {
      for (const p of source.payments.values()) {
        if (p.status === 'created' && p.method && Date.parse(p.createdAt) <= cutoff) {
          results.push(p);
          if (limit && results.length >= limit) return results;
        }
      }
    }
    return results;
  }

  async findOverduePayments(now: Date, limit?: number): Promise<readonly Payment[]> {
    const results: Payment[] = [];
    const nowMs = now.getTime();
    for (const source of this.sources) {
      for (const p of source.payments.values()) {
        if (p.status === 'created' && p.method && p.expiresAt && Date.parse(p.expiresAt) <= nowMs) {
          results.push(p);
          if (limit && results.length >= limit) return results;
        }
      }
    }
    return results;
  }
}
