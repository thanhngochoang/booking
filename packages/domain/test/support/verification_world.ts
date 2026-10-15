import { ControllableClock, SequentialIdGen } from './booking_world.js';
import { MemoryVerificationStore } from '../../src/memory_verification_store.js';
import type {
  AuthPhoneReader,
  IdentityVault,
  VerificationDeps,
} from '../../src/verification_ports.js';
import type { NotifyDeps } from '../../src/notification_ports.js';
import { createNotifyWorld } from './notify_world.js';
import type { MemoryNotificationStore } from '../../src/memory_notification_store.js';

export class MemoryIdentityVault implements IdentityVault {
  async hashId(idNumber: string): Promise<string> {
    const reversed = idNumber.split('').reverse().join('');
    return `h:${reversed}`;
  }

  async encryptId(idNumber: string): Promise<string> {
    return `enc:${idNumber}`;
  }
}

export class MapAuthPhoneReader implements AuthPhoneReader {
  readonly phones = new Map<string, string>();

  async verifiedPhoneOf(uid: string): Promise<string | null> {
    return this.phones.get(uid) ?? null;
  }
}

export interface VerificationWorld {
  readonly deps: VerificationDeps;
  readonly store: MemoryVerificationStore;
  readonly authPhones: MapAuthPhoneReader;
  readonly clock: ControllableClock;
  readonly ids: SequentialIdGen;
  readonly notifyDeps: NotifyDeps;
  /** The notification rows written through [notifyDeps]. */
  readonly notifyStore: MemoryNotificationStore;
}

export function createVerificationWorld(options: { feeRequired?: boolean } = {}): VerificationWorld {
  const store = new MemoryVerificationStore();
  const authPhones = new MapAuthPhoneReader();
  const clock = new ControllableClock(new Date('2026-10-10T10:00:00.000Z'));
  const ids = new SequentialIdGen('ver');

  // Seed p1 (individual, onboarded), s1 (studio, onboarded), c1 (customer)
  store.providers.set('p1', {
    providerType: 'individual',
    onboardingComplete: true,
    verified: false,
    businessVerified: false,
  });
  store.contacts.set('p1', {
    phone: '+84903123456',
    phoneVerified: false,
  });
  authPhones.phones.set('p1', '+84903123456');

  store.providers.set('s1', {
    providerType: 'studio',
    onboardingComplete: true,
    verified: false,
    businessVerified: false,
  });
  store.contacts.set('s1', {
    phone: '+84903999999',
    phoneVerified: false,
  });
  authPhones.phones.set('s1', '+84903999999');

  // c1 is customer only (not in store.providers)
  store.contacts.set('c1', {
    phone: '+84901111111',
    phoneVerified: true,
  });

  const deps: VerificationDeps = {
    store,
    authPhones,
    identity: null,
    vault: new MemoryIdentityVault(),
    taxCodes: null,
    feeRequired: options.feeRequired ?? false,
    clock,
    ids,
  };

  const notifyWorld = createNotifyWorld(clock.now());
  notifyWorld.users.users.set('p1', { name: 'Thợ P1', avatarUrl: null });
  notifyWorld.users.users.set('s1', { name: 'Studio S1', avatarUrl: null });
  notifyWorld.users.users.set('c1', { name: 'Khách C1', avatarUrl: null });

  return {
    deps,
    store,
    authPhones,
    clock,
    ids,
    notifyDeps: notifyWorld.deps,
    notifyStore: notifyWorld.store,
  };
}
