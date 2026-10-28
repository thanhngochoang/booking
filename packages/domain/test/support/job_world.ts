import { createNotifyWorld, type NotifyWorld } from './notify_world.js';
import type { IdGenerator, UserContactReader } from '../../src/ports.js';
import { FakeBlockGate } from '../../src/fake_block_gate.js';
import { MemoryJobStore } from '../../src/memory_job_store.js';
import type { MemoryNotificationStore } from '../../src/memory_notification_store.js';
import type { NotifyDeps } from '../../src/notification_ports.js';
import type { JobDeps, JobMedia, JobPeople } from '../../src/job_ports.js';
import type { JobProviderProfile } from '../../src/job_eligibility.js';
import type { ProviderOrderGate } from '../../src/booking_ports.js';

export class MemoryJobPeople implements JobPeople {
  readonly customers = new Map<
    string,
    { role: string | null; name: string; avatarUrl: string | null; phoneVerified: boolean; hireCount: number }
  >();
  readonly providers = new Map<string, JobProviderProfile>();
  readonly dayStates = new Map<string, Map<string, 'free' | 'pending' | 'booked' | 'off'>>(); // uid -> (day -> state)
  readonly dayBookingIds = new Map<string, Map<string, string>>();
  readonly services = new Map<
    string,
    { active: boolean; photoCount: number | null; editedCount: number | null; deliveryDays: number | null; price: number }
  >();
  readonly albums = new Map<
    string,
    { photographerId: string; title: string; coverUrl: string | null; postCount: number }
  >();

  async customer(uid: string) {
    return this.customers.get(uid) ?? null;
  }
  async provider(uid: string) {
    return this.providers.get(uid) ?? null;
  }
  async candidates(specialtyId: string, limit: number) {
    const list: JobProviderProfile[] = [];
    for (const p of this.providers.values()) {
      if (p.specialties.includes(specialtyId)) {
        list.push(p);
        if (list.length >= limit) break;
      }
    }
    return list;
  }
  async dayState(photographerId: string, day: string) {
    return this.dayStates.get(photographerId)?.get(day) ?? 'free';
  }
  async dayBookingId(photographerId: string, day: string) {
    return this.dayBookingIds.get(photographerId)?.get(day) ?? null;
  }
  async service(photographerId: string, serviceId: string) {
    return this.services.get(`${photographerId}_${serviceId}`) ?? null;
  }
  async album(albumId: string) {
    return this.albums.get(albumId) ?? null;
  }
}

export class MemoryJobMedia implements JobMedia {
  readonly deleted: string[] = [];

  isOwnReference(url: string, path: string, uid: string): boolean {
    return path.startsWith(`jobRefs/${uid}/`);
  }
  async deleteReference(path: string): Promise<void> {
    this.deleted.push(path);
  }
}

export interface JobTestWorld {
  deps: JobDeps;
  notifyDeps: NotifyDeps;
  notifyWorld: NotifyWorld;
  jobs: MemoryJobStore;
  people: MemoryJobPeople;
  media: MemoryJobMedia;
  blocks: FakeBlockGate;
  notifications: MemoryNotificationStore;
  clock: { now(): Date; set(d: Date): void };
}

export function createJobWorld(): JobTestWorld {
  let currentTime = new Date('2026-10-05T02:00:00.000Z');
  const clock = {
    now: () => new Date(currentTime.getTime()),
    set: (d: Date) => {
      currentTime = new Date(d.getTime());
    },
  };

  const jobs = new MemoryJobStore();
  const people = new MemoryJobPeople();
  const media = new MemoryJobMedia();
  const blocks = new FakeBlockGate();
  const notifyWorld = createNotifyWorld(currentTime);
  const notifications = notifyWorld.store;

  let idCounter = 1;
  const ids: IdGenerator = {
    newId: () => `job_id_${idCounter++}`,
  };

  const contacts: UserContactReader = {
    get: async (uid: string) => {
      if (uid === 'cust_lan') {
        return { phone: '+84903123456', email: 'lan@test.com', phoneVerified: true };
      }
      return null;
    },
  };

  const providers: ProviderOrderGate = {
    acceptsOrders: async (pid: string): Promise<boolean> => {
      const p = await people.provider(pid);
      if (!p) return false;
      return Boolean(p.acceptingOrdersFields.verified && p.acceptingOrdersFields.onboardingComplete);
    },
    orderProfile: async (pid: string) => {
      const p = await people.provider(pid);
      if (!p) return null;
      return {
        acceptsOrders: Boolean(p.acceptingOrdersFields.verified && p.acceptingOrdersFields.onboardingComplete),
        providerType: p.providerType,
      };
    },
  };

  // Seed customer Lan
  people.customers.set('cust_lan', {
    role: 'customer',
    name: 'Lan',
    avatarUrl: null,
    phoneVerified: true,
    hireCount: 1,
  });

  // Seed photographers: Tú, Studio Mây, Vũ, Bình, Hà
  // 1. Tú: individual, TP.HCM centre Quận 1, radius 20, specialties ['graduation','portrait'], starting price 3M
  people.providers.set('p_tu', {
    uid: 'p_tu',
    role: 'photographer',
    onboardingComplete: true,
    acceptingOrdersFields: { verified: true, onboardingComplete: true },
    providerType: 'individual',
    specialties: ['graduation', 'portrait'],
    serviceArea: {
      city: 'TP.HCM',
      radiusKm: 20,
      center: { lat: 10.7769, lng: 106.7009 },
    },
    startingPrice: 3000000,
    tomatoPct: 95,
    score: 1.0,
    reviewCount: 10,
    completedCount: 20,
    approvedAwardCount: 0,
    verified: true,
    name: 'Tú',
    avatarUrl: null,
    studioDistrict: null,
  });

  // 2. Studio Mây: studio, TP.HCM
  people.providers.set('p_may', {
    uid: 'p_may',
    role: 'photographer',
    onboardingComplete: true,
    acceptingOrdersFields: { verified: true, onboardingComplete: true },
    providerType: 'studio',
    specialties: ['graduation', 'portrait'],
    serviceArea: {
      city: 'TP.HCM',
      radiusKm: 30,
      center: { lat: 10.7769, lng: 106.7009 },
    },
    startingPrice: 2500000,
    tomatoPct: 93,
    score: 0.9,
    reviewCount: 25,
    completedCount: 50,
    approvedAwardCount: 0,
    verified: true,
    name: 'Studio Mây',
    avatarUrl: null,
    studioDistrict: 'Quận 1',
  });

  // 3. Vũ: artist, TP.HCM
  people.providers.set('p_vu', {
    uid: 'p_vu',
    role: 'photographer',
    onboardingComplete: true,
    acceptingOrdersFields: { verified: true, onboardingComplete: true },
    providerType: 'artist',
    specialties: ['portrait', 'wedding'],
    serviceArea: {
      city: 'TP.HCM',
      radiusKm: 20,
      center: { lat: 10.7769, lng: 106.7009 },
    },
    startingPrice: 4200000,
    tomatoPct: 97,
    score: 1.0,
    reviewCount: 30,
    completedCount: 64,
    approvedAwardCount: 7,
    verified: true,
    name: 'Lê Hoàng Vũ',
    avatarUrl: null,
    studioDistrict: null,
  });

  // 4. Bình: TP.HCM, not accepting orders
  people.providers.set('p_binh', {
    uid: 'p_binh',
    role: 'photographer',
    onboardingComplete: true,
    acceptingOrdersFields: { verified: false, onboardingComplete: false },
    providerType: 'individual',
    specialties: ['portrait'],
    serviceArea: {
      city: 'TP.HCM',
      radiusKm: 20,
      center: { lat: 10.7769, lng: 106.7009 },
    },
    startingPrice: 2000000,
    tomatoPct: 80,
    score: 0.8,
    reviewCount: 2,
    completedCount: 2,
    approvedAwardCount: 0,
    verified: false,
    name: 'Bình',
    avatarUrl: null,
    studioDistrict: null,
  });

  // 5. Hà: individual, Hà Nội, no centre
  people.providers.set('p_ha', {
    uid: 'p_ha',
    role: 'photographer',
    onboardingComplete: true,
    acceptingOrdersFields: { verified: true, onboardingComplete: true },
    providerType: 'individual',
    specialties: ['portrait'],
    serviceArea: {
      city: 'Hà Nội',
      radiusKm: 20,
      center: null,
    },
    startingPrice: 2000000,
    tomatoPct: 90,
    score: 0.9,
    reviewCount: 8,
    completedCount: 15,
    approvedAwardCount: 0,
    verified: true,
    name: 'Hà',
    avatarUrl: null,
    studioDistrict: null,
  });

  const deps: JobDeps = {
    jobs,
    people,
    contacts,
    media,
    clock,
    ids,
    providers,
    blocks,
  };

  const notifyDeps: NotifyDeps = notifyWorld.deps;

  return { deps, notifyDeps, notifyWorld, jobs, people, media, blocks, notifications, clock };
}
