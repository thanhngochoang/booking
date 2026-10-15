import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  FcmPushSender,
  LoggingPushSender,
  type DeviceDirectory,
  type MulticastMessaging,
} from '../../src/infra/fcm_push.js';

function setup(responses: Array<{ success: boolean; code?: string }>) {
  const sent: Array<Parameters<MulticastMessaging['sendEachForMulticast']>[0]> = [];
  const removed: string[] = [];
  const devices: DeviceDirectory = {
    devicesOf: async () => [
      { id: 'u1_A', token: 't1' },
      { id: 'u1_B', token: 't2' },
    ],
    remove: async (ids) => { removed.push(...ids); },
  };
  const messaging: MulticastMessaging = {
    sendEachForMulticast: async (m) => {
      sent.push(m);
      return { responses: responses.map((r) => ({ success: r.success, ...(r.code ? { error: { code: r.code } } : {}) })) };
    },
  };
  return { sender: new FcmPushSender(devices, messaging), sent, removed };
}

const msg = (channel: 'default' | 'quiet') => ({
  title: 'T',
  body: 'B',
  channel,
  data: { type: 'booking_accepted', target: '/b/x', notificationId: 'n_1' },
});

describe('FCM push sender', () => {
  it('uses the quiet channel and normal priority at night', async () => {
    const { sender, sent } = setup([{ success: true }, { success: true }]);
    await sender.send('u1', msg('quiet'));
    await sender.send('u1', msg('default'));
    assert.equal(sent[0]?.android.priority, 'normal');
    assert.equal(sent[0]?.android.notification.channelId, 'quiet');
    assert.equal(sent[1]?.android.priority, 'high');
    assert.equal(sent[1]?.android.notification.channelId, 'default');
    assert.deepEqual(sent[0]?.tokens, ['t1', 't2']);
    assert.deepEqual(sent[0]?.data, { type: 'booking_accepted', target: '/b/x', notificationId: 'n_1' });
  });

  it('dead tokens are deleted, others kept', async () => {
    const { sender, removed } = setup([
      { success: false, code: 'messaging/registration-token-not-registered' },
      { success: false, code: 'messaging/internal-error' },
    ]);
    await sender.send('u1', msg('default'));
    assert.deepEqual(removed, ['u1_A']);
    const both = setup([
      { success: false, code: 'messaging/invalid-registration-token' },
      { success: true },
    ]);
    await both.sender.send('u1', msg('default'));
    assert.deepEqual(both.removed, ['u1_A']);
  });

  it('a user without devices sends nothing', async () => {
    const sent: unknown[] = [];
    const sender = new FcmPushSender(
      { devicesOf: async () => [], remove: async () => {} },
      { sendEachForMulticast: async (m) => { sent.push(m); return { responses: [] }; } },
    );
    await sender.send('u1', msg('default'));
    assert.equal(sent.length, 0);
  });

  it('emulator sender only logs', async () => {
    await new LoggingPushSender().send('u1', msg('default'));
  });
});
