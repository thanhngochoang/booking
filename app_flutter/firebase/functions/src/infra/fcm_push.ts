import type { Firestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import * as logger from 'firebase-functions/logger';
import type { PushMessage, PushSender } from '@photobooking/domain';

/** FCM error codes that mean the token will never work again. */
export const DEAD_TOKEN_CODES: readonly string[] = [
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
];

const MAX_DEVICES = 10;

export interface DeviceRef {
  readonly id: string;
  readonly token: string;
}

/** Where the sender finds a user's devices and drops dead ones. */
export interface DeviceDirectory {
  devicesOf(uid: string, limit: number): Promise<DeviceRef[]>;
  remove(ids: readonly string[]): Promise<void>;
}

export interface MulticastResult {
  readonly responses: ReadonlyArray<{ readonly success: boolean; readonly error?: { readonly code?: string } }>;
}

/** The slice of `firebase-admin/messaging` the sender uses. */
export interface MulticastMessaging {
  sendEachForMulticast(message: {
    tokens: string[];
    notification: { title: string; body: string };
    data: Record<string, string>;
    android: { priority: 'high' | 'normal'; notification: { channelId: string } };
  }): Promise<MulticastResult>;
}

export class FirestoreDeviceDirectory implements DeviceDirectory {
  constructor(private readonly db: Firestore) {}

  async devicesOf(uid: string, limit: number): Promise<DeviceRef[]> {
    const snap = await this.db.collection('devices').where('userId', '==', uid).limit(limit).get();
    const out: DeviceRef[] = [];
    for (const d of snap.docs) {
      const token: unknown = d.data().token;
      if (typeof token === 'string' && token !== '') out.push({ id: d.id, token });
    }
    return out;
  }

  async remove(ids: readonly string[]): Promise<void> {
    if (ids.length === 0) return;
    const batch = this.db.batch();
    for (const id of ids) batch.delete(this.db.collection('devices').doc(id));
    await batch.commit();
  }
}

/** Sends to every device of the user; the quiet channel is also sent with normal priority. */
export class FcmPushSender implements PushSender {
  constructor(
    private readonly devices: DeviceDirectory,
    private readonly messaging: MulticastMessaging = getMessaging() as unknown as MulticastMessaging,
  ) {}

  async send(uid: string, msg: PushMessage): Promise<void> {
    const devices = await this.devices.devicesOf(uid, MAX_DEVICES);
    if (devices.length === 0) return;
    const data: Record<string, string> = { type: msg.data.type, target: msg.data.target };
    if (msg.data.notificationId !== undefined) data.notificationId = msg.data.notificationId;
    const res = await this.messaging.sendEachForMulticast({
      tokens: devices.map((d) => d.token),
      notification: { title: msg.title, body: msg.body },
      data,
      android: { priority: msg.channel === 'quiet' ? 'normal' : 'high', notification: { channelId: msg.channel } },
    });
    const dead: string[] = [];
    res.responses.forEach((r, i) => {
      const device = devices[i];
      if (!r.success && device !== undefined && r.error?.code !== undefined && DEAD_TOKEN_CODES.includes(r.error.code)) {
        dead.push(device.id);
      }
    });
    if (dead.length > 0) await this.devices.remove(dead);
  }
}

/** Emulator sender: logs the type only, never the text or a token. */
export class LoggingPushSender implements PushSender {
  async send(uid: string, msg: PushMessage): Promise<void> {
    logger.info('push (emulator, not sent)', { uid, type: msg.data.type, channel: msg.channel });
  }
}
