// services/api/tools/firestore-import/memory-source.ts
import type { DocSource } from './export.js';

/** In-memory Firestore stand-in keyed by document path ("users/u1", "users/u1/private/contact"). */
export function memorySource(docs: Record<string, Record<string, unknown>>): DocSource {
  return {
    async *list(collection: string) {
      for (const [path, data] of Object.entries(docs)) {
        const parts = path.split('/');
        if (parts.length === 2 && parts[0] === collection) yield { id: parts[1]!, data };
      }
    },
    async get(path: string) {
      return docs[path] ?? null;
    },
  };
}

const ts = (iso: string) => ({ toDate: () => new Date(iso) });

/** Two valid users, one invalid id, one malformed customer phone, one orphan photographer. */
export const FIXTURE: Record<string, Record<string, unknown>> = {
  'users/u_lan': {
    displayName: 'Lan', role: 'customer', avatarUrl: 'https://lh3.googleusercontent.com/a/lan.jpg',
    createdAt: ts('2026-09-01T00:00:00Z'), updatedAt: ts('2026-09-02T00:00:00Z'),
  },
  'users/u_lan/private/contact': { phone: '+84903123456', allowZalo: true, allowWhatsApp: false, phoneVerified: false },
  'users/p_minh': { displayName: 'Minh', role: 'photographer' },
  'users/p_minh/private/contact': { phone: '0903123456' },
  'photographers/p_minh': {
    bio: 'Chân dung', yearsExperience: 5, providerType: 'studio', studioDistrict: 'Ba Đình', studioCity: 'Hà Nội', approvedAwardCount: 2, onboardingComplete: true, verified: false,
    serviceArea: { city: 'Hà Nội', radiusKm: 20, center: { latitude: 21.03, longitude: 105.85 } },
    contactChannels: { call: true, zalo: true, whatsapp: false, acceptInquiries: true },
  },
  'photographers/p_minh/private/contact': { phone: '+84912345678', zaloPhone: '+84987654321' },
  'photographers/p_minh/private/studioAddress': { line: '1 Kim Mã', ward: 'Kim Mã', district: 'Ba Đình', city: 'Hà Nội', lat: 21.03, lng: 105.82 },
  'users/bad$id': { displayName: 'X' },
  'photographers/p_ghost': { bio: '' },
};
