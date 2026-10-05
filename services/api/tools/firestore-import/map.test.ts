// services/api/tools/firestore-import/map.test.ts
import { describe, expect, it } from 'vitest';

import { mapPhotographer, mapPhotographerNumbers, mapStudioAddress, mapUser, mapUserContact, toIso } from './map.js';

describe('Firestore → row mapping (relational-schema.md §3)', () => {
  it('turns Timestamps, Dates and ISO strings into ISO-8601 UTC; junk into null', () => {
    expect(toIso({ toDate: () => new Date('2026-09-01T07:00:00+07:00') })).toBe('2026-09-01T00:00:00.000Z');
    expect(toIso(new Date(Date.UTC(2026, 0, 1)))).toBe('2026-01-01T00:00:00.000Z');
    expect(toIso('2026-01-01T00:00:00Z')).toBe('2026-01-01T00:00:00.000Z');
    expect(toIso(1735689600000)).toBeNull();
    expect(toIso(undefined)).toBeNull();
  });

  it('users: keeps the uid, maps the avatar to an external file, rejects bad ids and roles', () => {
    const m = mapUser('u1', { displayName: 'Lan', role: 'customer', avatarUrl: 'https://x.test/a.jpg' });
    expect(m).toEqual({
      ok: true,
      value: {
        user: { id: 'u1', display_name: 'Lan', role: 'customer', avatar_file_id: 'avatar_u1', created_at: null, updated_at: null },
        file: { id: 'avatar_u1', storage_provider: 'external', storage_key: 'https://x.test/a.jpg', mime_type: 'image/*', size_bytes: 0, owner_user_id: 'u1' },
      },
    });
    expect(mapUser('a$b', {}).ok).toBe(false);
    expect(mapUser('u1', { role: 'admin' }).ok).toBe(false);
    expect(mapUser('u1', {})).toMatchObject({ ok: true, value: { user: { display_name: '', role: null }, file: null } });
  });

  it('user contacts: E.164 only, documented defaults', () => {
    expect(mapUserContact('u1', { phone: '+84903123456' })).toEqual({
      ok: true,
      value: { user_id: 'u1', phone_e164: '+84903123456', phone_verified: false, allow_zalo: true, allow_whatsapp: false, updated_at: null },
    });
    expect(mapUserContact('u1', { phone: '0903123456' })).toEqual({ ok: false, reason: 'phone is not E.164' });
  });

  it('photographers: flattened area, centre, flags and acceptInquiries', () => {
    const m = mapPhotographer('p1', {
      bio: 'x', yearsExperience: 60, onboardingComplete: true,
      serviceArea: { city: 'Huế', radiusKm: 15, center: { latitude: 16.46, longitude: 107.59 } },
      contactChannels: { zalo: true, acceptInquiries: false },
    });
    expect(m).toEqual({
      ok: true,
      value: {
        photographer: {
          user_id: 'p1', bio: 'x', years_experience: null, service_city: 'Huế', service_lat: 16.46, service_lng: 107.59,
          service_radius_km: 15, verified: false, onboarding_complete: true, accepts_inquiries: false, created_at: null, updated_at: null,
          provider_type: 'individual', artist_since: null, studio_district: null, studio_city: null, approved_award_count: 0,
        },
        channels: { photographer_id: 'p1', call_enabled: false, zalo_enabled: true, whatsapp_enabled: false },
      },
    });
  });

  it('photographer numbers: main number required, optional ones must be valid when present', () => {
    expect(mapPhotographerNumbers('p1', { phone: '+84903123456' })).toEqual({
      ok: true, value: { photographer_id: 'p1', phone_e164: '+84903123456', zalo_phone_e164: null, whatsapp_phone_e164: null },
    });
    expect(mapPhotographerNumbers('p1', { phone: '+84903123456', whatsappPhone: '14155552671' }).ok).toBe(false);
    expect(mapPhotographerNumbers('p1', {}).ok).toBe(false);
  });

  it('a Firestore photographer without providerType maps to individual; unknown values too', () => {
    const base = mapPhotographer('p1', { bio: 'x' });
    expect(base).toMatchObject({ ok: true, value: { photographer: { provider_type: 'individual', approved_award_count: 0, artist_since: null } } });
    expect(mapPhotographer('p1', { providerType: 'agency' })).toMatchObject({ value: { photographer: { provider_type: 'individual' } } });
    const s = mapPhotographer('p1', {
      providerType: 'studio', studioDistrict: 'Quận 1', studioCity: 'TP.HCM', approvedAwardCount: 3,
      artistSince: { toDate: () => new Date('2026-09-01T00:00:00Z') },
    });
    expect(s).toMatchObject({
      value: { photographer: { provider_type: 'studio', studio_district: 'Quận 1', studio_city: 'TP.HCM', approved_award_count: 3, artist_since: '2026-09-01T00:00:00.000Z' } },
    });
  });

  it('studioAddress private doc maps to studio_addresses', () => {
    expect(mapStudioAddress('p1', { line: '12 Lê Lợi', ward: 'Bến Nghé', district: 'Quận 1', city: 'TP.HCM', lat: 10.77, lng: 106.7, point: {}, updatedAt: new Date('2026-10-01T00:00:00Z') })).toEqual({
      ok: true,
      value: { photographer_id: 'p1', line: '12 Lê Lợi', ward: 'Bến Nghé', district: 'Quận 1', city: 'TP.HCM', lat: 10.77, lng: 106.7, updated_at: '2026-10-01T00:00:00.000Z' },
    });
    expect(mapStudioAddress('p1', { line: 'x', district: 'd', city: 'c' })).toMatchObject({ ok: true, value: { ward: null, lat: null, lng: null } });
    expect(mapStudioAddress('p1', { line: 'x', city: 'c' }).ok).toBe(false);
  });
});
