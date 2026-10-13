import {
  PAYMENT_METHODS,
  type Payment,
  type PaymentLookup,
  type TransferRecord,
} from '@photobooking/domain';
import {
  Timestamp,
  type Firestore,
} from 'firebase-admin/firestore';
import {
  PAYMENTS_COLLECTION,
  PAYMENT_NOTIFICATIONS_COLLECTION,
  paymentFromFirestore,
  transferRecordFromFirestore,
  transferRecordToFirestore,
} from './booking_firestore.js';

export class FirestorePaymentLookup implements PaymentLookup {
  constructor(private readonly firestore: Firestore) {}

  async getPayment(id: string): Promise<Payment | null> {
    const s = await this.firestore.collection(PAYMENTS_COLLECTION).doc(id).get();
    return s.exists ? paymentFromFirestore(s.id, s.data()) : null;
  }

  async findPaymentsByTransferCode(code: string): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('transferCode', '==', code)
      .get();
    const res: Payment[] = [];
    for (const d of snap.docs) {
      const p = paymentFromFirestore(d.id, d.data());
      if (p) res.push(p);
    }
    return res;
  }

  async getTransferRecord(id: string): Promise<TransferRecord | null> {
    const s = await this.firestore.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(id).get();
    return s.exists ? transferRecordFromFirestore(s.id, s.data()) : null;
  }

  async saveUnmatchedTransfer(record: TransferRecord): Promise<void> {
    try {
      await this.firestore
        .collection(PAYMENT_NOTIFICATIONS_COLLECTION)
        .doc(record.id)
        .create(transferRecordToFirestore(record));
    } catch (e: unknown) {
      // 6 is ALREADY_EXISTS in gRPC / Firestore
      if (
        e &&
        typeof e === 'object' &&
        ('code' in e && (e as { code?: unknown }).code === 6 ||
         'code' in e && (e as { code?: unknown }).code === 'already-exists')
      ) {
        return;
      }
      throw e;
    }
  }

  async findPaymentsToReconcile(createdBefore: Date, limit = 100): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('status', '==', 'created')
      .where('method', 'in', PAYMENT_METHODS as readonly string[])
      .where('createdAt', '<=', Timestamp.fromDate(createdBefore))
      .limit(limit)
      .get();
    const res: Payment[] = [];
    for (const d of snap.docs) {
      const p = paymentFromFirestore(d.id, d.data());
      if (p) res.push(p);
    }
    return res;
  }

  async findOverduePayments(now: Date, limit = 100): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('status', '==', 'created')
      .where('method', 'in', PAYMENT_METHODS as readonly string[])
      .where('expiresAt', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const res: Payment[] = [];
    for (const d of snap.docs) {
      const p = paymentFromFirestore(d.id, d.data());
      if (p) res.push(p);
    }
    return res;
  }
}
