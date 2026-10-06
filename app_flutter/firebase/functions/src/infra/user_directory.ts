import type { Firestore } from 'firebase-admin/firestore';
import type { UserDirectory } from '@photobooking/domain';

/** Public name and avatar from `users/{uid}`. */
export class FirestoreUserDirectory implements UserDirectory {
  constructor(private readonly db: Firestore) {}

  async get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> {
    const snap = await this.db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    const d = snap.data();
    return {
      name: typeof d?.displayName === 'string' && d.displayName !== '' ? d.displayName : 'Người dùng',
      avatarUrl: typeof d?.avatarUrl === 'string' && d.avatarUrl !== '' ? d.avatarUrl : null,
    };
  }
}
