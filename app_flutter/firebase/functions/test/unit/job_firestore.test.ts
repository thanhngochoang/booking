import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import type { JobRecord, QuoteRecord, JobInviteRecord, JobMatchRecord } from '@photobooking/domain';
import {
  jobToFirestore,
  jobFromFirestore,
  quoteToFirestore,
  quoteFromFirestore,
  inviteToFirestore,
  inviteFromFirestore,
  matchToFirestore,
  matchFromFirestore,
} from '../../src/infra/job_firestore.js';

describe('job Firestore mapping', () => {
  const sampleJob: JobRecord = {
    id: '01ARZ3NDEKTSV4RRFFQ69G5F01',
    customerId: 'cust_lan',
    customer: {
      name: 'Lan',
      avatarUrl: 'https://img.test/lan.jpg',
      hireCount: 3,
      phoneVerified: true,
    },
    specialtyId: 'portrait',
    title: 'Chụp chân dung tốt nghiệp ở Văn Miếu',
    description: 'Cần tìm thợ chụp kỷ yếu phong cách tự nhiên, thời gian 2 tiếng.',
    references: [{ url: 'https://img.test/ref1.jpg', path: 'jobRefs/cust_lan/draft_1/1.jpg' }],
    schedule: {
      kind: 'fixed',
      day: '2026-11-01',
      start: '08:00',
      end: '10:00',
      from: null,
      to: null,
      durationMinutes: 120,
    },
    dayFrom: '2026-11-01',
    dayTo: '2026-11-01',
    area: {
      areaId: 'hn-hoan-kiem',
      name: 'Quận Hoàn Kiếm, Hà Nội',
      city: 'Hà Nội',
      cityKey: 'hanoi',
      lat: 21.0285,
      lng: 105.8542,
      geohash5: 'w7er8',
    },
    budget: { min: 1_000_000, max: 2_000_000 },
    wants: { editedCount: 30, deliveryDays: 7 },
    allowedProviders: 'all',
    quoteDeadline: new Date('2026-10-25T12:00:00.000Z'),
    extended: false,
    status: 'open',
    quoteCount: 1,
    newQuoteCount: 1,
    viewCount: 5,
    inviteCount: 1,
    matchCount: 3,
    recentQuoters: [{ photographerId: 'photog_an', avatarUrl: 'https://img.test/an.jpg' }],
    awardedQuoteId: null,
    bookingId: null,
    awardedTo: null,
    checkout: null,
    expiringNotifiedAt: null,
    closedAt: null,
    referencesPurgeAfter: null,
    quotesSeenAt: null,
    version: 1,
    createdAt: new Date('2026-10-21T10:00:00.000Z'),
    updatedAt: new Date('2026-10-21T10:00:00.000Z'),
  };

  const sampleQuote: QuoteRecord = {
    id: 'photog_an',
    jobId: '01ARZ3NDEKTSV4RRFFQ69G5F01',
    photographerId: 'photog_an',
    customerId: 'cust_lan',
    jobTitle: 'Chụp chân dung tốt nghiệp ở Văn Miếu',
    photographer: {
      name: 'An',
      avatarUrl: 'https://img.test/an.jpg',
      providerType: 'individual',
      verified: true,
      tomatoPct: 95,
      score: 4.8,
      reviewCount: 20,
      completedCount: 25,
      approvedAwardCount: 2,
      studioDistrict: null,
    },
    basedOnServiceId: 'service_portrait_01',
    terms: {
      price: 1_800_000,
      durationMinutes: 120,
      photoCount: 50,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 1,
      milestones: [
        { kind: 'shoot', percent: 50 },
        { kind: 'delivery', percent: 50 },
      ],
    },
    milestoneAmounts: { shoot: 900_000, delivery: 900_000 },
    proposal: { day: '2026-11-01', start: '08:00', end: '10:00' },
    message: 'Mình chụp chân dung tốt nghiệp nhiều năm, quen góc Văn Miếu buổi sáng.',
    albumId: 'album_01',
    album: { title: 'Tốt nghiệp', coverUrl: 'https://img.test/cover.jpg', postCount: 12 },
    invited: false,
    fit: 88,
    status: 'submitted',
    notSelectedReason: null,
    autoWithdrawn: false,
    declineReason: null,
    bookingId: null,
    withdrawnAt: null,
    version: 1,
    createdAt: new Date('2026-10-21T11:00:00.000Z'),
    updatedAt: new Date('2026-10-21T11:00:00.000Z'),
  };

  it('job round-trips through the mappers with Timestamps for instants', () => {
    const data = jobToFirestore(sampleJob);
    assert.ok(data.quoteDeadline instanceof Timestamp);
    assert.ok(data.createdAt instanceof Timestamp);
    assert.ok(data.updatedAt instanceof Timestamp);
    assert.equal(data.checkout, null);

    const restored = jobFromFirestore(sampleJob.id, data);
    assert.deepEqual(restored, sampleJob);
  });

  it('quote round-trips with terms and milestone amounts', () => {
    const data = quoteToFirestore(sampleQuote);
    assert.ok(data.createdAt instanceof Timestamp);
    assert.ok(data.updatedAt instanceof Timestamp);
    assert.deepEqual(data.milestoneAmounts, { shoot: 900_000, delivery: 900_000 });
    assert.equal(data.terms.price, 1_800_000);

    const restored = quoteFromFirestore(sampleQuote.id, data);
    assert.deepEqual(restored, sampleQuote);
  });

  it('a missing optional field reads as null', () => {
    const data = jobToFirestore({
      ...sampleJob,
      budget: null,
      awardedQuoteId: null,
      bookingId: null,
      awardedTo: null,
      checkout: null,
      expiringNotifiedAt: null,
      closedAt: null,
      referencesPurgeAfter: null,
      quotesSeenAt: null,
    });
    // simulate missing properties in firestore doc
    delete data.budget;
    delete data.awardedQuoteId;
    delete data.bookingId;
    delete data.awardedTo;
    delete data.checkout;
    delete data.expiringNotifiedAt;
    delete data.closedAt;
    delete data.referencesPurgeAfter;
    delete data.quotesSeenAt;

    const restored = jobFromFirestore(sampleJob.id, data);
    assert.ok(restored);
    assert.equal(restored.budget, null);
    assert.equal(restored.awardedQuoteId, null);
    assert.equal(restored.bookingId, null);
    assert.equal(restored.awardedTo, null);
    assert.equal(restored.checkout, null);
    assert.equal(restored.expiringNotifiedAt, null);
    assert.equal(restored.closedAt, null);
    assert.equal(restored.referencesPurgeAfter, null);
    assert.equal(restored.quotesSeenAt, null);
  });

  it('an unknown status is rejected (returns null)', () => {
    const data = jobToFirestore(sampleJob);
    data.status = 'unknown_future_status';
    assert.equal(jobFromFirestore(sampleJob.id, data), null);

    const quoteData = quoteToFirestore(sampleQuote);
    quoteData.status = 'invalid_quote_status';
    assert.equal(quoteFromFirestore(sampleQuote.id, quoteData), null);
  });

  it('invite and match round-trip through mappers', () => {
    const invite: JobInviteRecord = {
      id: 'photog_an',
      jobId: sampleJob.id,
      photographerId: 'photog_an',
      customerId: 'cust_lan',
      fit: 85,
      jobStatus: 'open',
      createdAt: new Date('2026-10-21T10:30:00.000Z'),
      seenAt: null,
    };
    const inviteData = inviteToFirestore(invite);
    assert.ok(inviteData.createdAt instanceof Timestamp);
    assert.equal(inviteData.seenAt, null);
    assert.deepEqual(inviteFromFirestore(invite.id, inviteData), invite);

    const match: JobMatchRecord = {
      id: 'photog_an',
      jobId: sampleJob.id,
      photographerId: 'photog_an',
      fit: 90,
      jobStatus: 'open',
      createdAt: new Date('2026-10-21T10:05:00.000Z'),
    };
    const matchData = matchToFirestore(match);
    assert.ok(matchData.createdAt instanceof Timestamp);
    assert.deepEqual(matchFromFirestore(match.id, matchData), match);
  });

  it('liveJobDeps wires a BlockGate', async () => {
    const { liveJobDeps } = await import('../../src/infra/live_job.js');
    const deps = liveJobDeps();
    assert.ok(deps.blocks !== undefined);
  });
});
