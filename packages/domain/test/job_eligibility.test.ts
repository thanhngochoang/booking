import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { JobProviderProfile } from '../src/job_eligibility.js';
import {
  jobInServiceArea,
  jobFit,
  providerTypeAllowed,
} from '../src/job_eligibility.js';
import type { JobRecord } from '../src/job.js';

describe('job eligibility & fit', () => {
  const baseJob: JobRecord = {
    id: 'job_01',
    customerId: 'cust_01',
    customer: { name: 'Lan', avatarUrl: null, hireCount: 2, phoneVerified: true },
    specialtyId: 'portrait',
    title: 'Kỷ yếu lớp 12A1',
    description: 'Chụp kỷ yếu',
    references: [],
    schedule: { kind: 'fixed', day: '2026-10-20', start: '07:00', end: '11:00', from: null, to: null, durationMinutes: 240 },
    dayFrom: '2026-10-20',
    dayTo: '2026-10-20',
    area: {
      areaId: 'q1',
      name: 'Quận 1, TP.HCM',
      city: 'TP.HCM',
      cityKey: 'tphcm',
      lat: 10.7769,
      lng: 106.7009,
      geohash5: 'w4gxd',
    },
    budget: { min: 3000000, max: 5000000 },
    wants: { editedCount: 40, deliveryDays: 7 },
    allowedProviders: 'all',
    quoteDeadline: new Date('2026-10-08T02:00:00.000Z'),
    extended: false,
    status: 'open',
    quoteCount: 0,
    newQuoteCount: 0,
    viewCount: 0,
    inviteCount: 0,
    matchCount: 0,
    recentQuoters: [],
    awardedQuoteId: null,
    bookingId: null,
    awardedTo: null,
    checkout: null,
    expiringNotifiedAt: null,
    closedAt: null,
    referencesPurgeAfter: null,
    quotesSeenAt: null,
    version: 1,
    createdAt: new Date('2026-10-05T02:00:00.000Z'),
    updatedAt: new Date('2026-10-05T02:00:00.000Z'),
  };

  const baseProvider: JobProviderProfile = {
    uid: 'p1',
    role: 'photographer',
    onboardingComplete: true,
    acceptingOrdersFields: { verified: true, onboardingComplete: true },
    providerType: 'individual',
    specialties: ['portrait', 'graduation'],
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
    approvedAwardCount: 3,
    verified: true,
    name: 'Tú',
    avatarUrl: null,
    studioDistrict: null,
  };

  it('inside the radius when a centre exists', () => {
    assert.equal(jobInServiceArea(baseJob.area, baseProvider.serviceArea), true);
  });

  it('outside the radius is not in area', () => {
    const farArea = { ...baseJob.area, lat: 11.5, lng: 107.5 }; // ~100km away
    assert.equal(jobInServiceArea(farArea, baseProvider.serviceArea), false);
  });

  it('same city key without a centre', () => {
    const areaNoCenter = { city: 'TP.HCM', radiusKm: 20, center: null };
    assert.equal(jobInServiceArea(baseJob.area, areaNoCenter), true);
  });

  it('another city without a centre is not in area', () => {
    const hanoiArea = { city: 'Hà Nội', radiusKm: 20, center: null };
    assert.equal(jobInServiceArea(baseJob.area, hanoiArea), false);
  });

  it('no service area is not in area', () => {
    assert.equal(jobInServiceArea(baseJob.area, null), false);
  });

  it('all allows every type, artist only artist, studio only studio', () => {
    assert.equal(providerTypeAllowed('all', 'individual'), true);
    assert.equal(providerTypeAllowed('all', 'artist'), true);
    assert.equal(providerTypeAllowed('all', 'studio'), true);

    assert.equal(providerTypeAllowed('artist', 'individual'), false);
    assert.equal(providerTypeAllowed('artist', 'artist'), true);
    assert.equal(providerTypeAllowed('artist', 'studio'), false);

    assert.equal(providerTypeAllowed('studio', 'individual'), false);
    assert.equal(providerTypeAllowed('studio', 'artist'), false);
    assert.equal(providerTypeAllowed('studio', 'studio'), true);
  });

  it('fit is 100 for a perfect match', () => {
    const fit = jobFit(baseJob, baseProvider, 'free');
    assert.equal(fit, 100);
  });

  it('fit drops with a busy day by 20', () => {
    const fitFree = jobFit(baseJob, baseProvider, 'free');
    const fitBusy = jobFit(baseJob, baseProvider, 'busy');
    assert.equal(fitFree - fitBusy, 20);
  });

  it('fit is an integer within 0..100 for random inputs', () => {
    const specialties = ['portrait', 'graduation', 'wedding', 'event', 'product', 'other'];
    const days: ('free' | 'pending' | 'busy')[] = ['free', 'pending', 'busy'];
    for (let i = 0; i < 200; i++) {
      const p: JobProviderProfile = {
        ...baseProvider,
        specialties: [specialties[i % specialties.length]],
        startingPrice: Math.floor(Math.random() * 10_000_000),
        score: Math.random() * 2 - 1,
        reviewCount: Math.floor(Math.random() * 50),
        completedCount: Math.floor(Math.random() * 50),
        serviceArea: {
          city: 'TP.HCM',
          radiusKm: 10 + Math.random() * 30,
          center: { lat: 10.7 + Math.random() * 0.2, lng: 106.6 + Math.random() * 0.2 },
        },
      };
      const day = days[i % days.length];
      const fit = jobFit(baseJob, p, day);
      assert.ok(Number.isInteger(fit), `fit ${fit} must be an integer`);
      assert.ok(fit >= 0 && fit <= 100, `fit ${fit} must be within 0..100`);
    }
  });
});
