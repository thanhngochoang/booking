import {
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
} from '../../src/memory_notification_store.js';
import type { NotifyDeps } from '../../src/notification_ports.js';
import { ControllableClock } from './booking_world.js';

export interface NotifyWorld {
  readonly deps: NotifyDeps;
  readonly store: MemoryNotificationStore;
  readonly push: MemoryPushSender;
  readonly users: MemoryUserDirectory;
  readonly clock: ControllableClock;
  readonly pushErrors: unknown[];
}

/** 2026-10-10 10:00 UTC = 17:00 in Vietnam: outside quiet hours. */
export function createNotifyWorld(start = new Date('2026-10-10T10:00:00.000Z')): NotifyWorld {
  const store = new MemoryNotificationStore();
  const push = new MemoryPushSender();
  const users = new MemoryUserDirectory();
  const clock = new ControllableClock(start);
  const pushErrors: unknown[] = [];
  return {
    store,
    push,
    users,
    clock,
    pushErrors,
    deps: { store, push, users, clock, onPushError: (_uid, e) => pushErrors.push(e) },
  };
}
