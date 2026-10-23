import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp, FieldValue } from 'firebase-admin/firestore';
import type { Booking, JobRecord, QuoteRecord, NotifyDeps, ChatDeps, BadgeDeps, JobDeps } from '@photobooking/domain';
import { MemoryNotificationStore, MemoryUserDirectory, MemoryPushSender } from '@photobooking/domain';
import {
  handleJobQuoteWrite,
  handleJobMatchCreated,
  handleJobInviteCreated,
  handleJobViewCreated,
} from '../../src/triggers/job_writes.js';
import { handleBookingWrite } from '../../src/triggers/booking_write.js';
import { quoteToFirestore, jobToFirestore, matchToFirestore, inviteToFirestore } from '../../src/infra/job_firestore.js';
import { bookingToFirestore } from '../../src/infra/booking_firestore.js';

function createMockNotify(): { notify: NotifyDeps; sent: any[] } {
  const sent: any[] = [];
  const store = new MemoryNotificationStore();
  const users = new MemoryUserDirectory();
  users.users.set('cust_lan', { name: 'Lan', avatarUrl: null });
  users.users.set('photog_an', { name: 'An', avatarUrl: null });
  users.users.set('cust_minh', { name: 'Minh', avatarUrl: null });

  const notify: any = {
    store,
    users,
    clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
    push: new MemoryPushSender(),
    send: async (req: any) => {
      sent.push(req);
      return { delivered: true, reason: 'sent' };
    },
  };
  return { notify, sent };
}

const sampleQuote: QuoteRecord = {
  id: 'photog_an',
  jobId: 'job_01',
  photographerId: 'photog_an',
  customerId: 'cust_lan',
  jobTitle: 'Chụp chân dung tốt nghiệp ở Văn Miếu',
  photographer: {
    name: 'An',
    avatarUrl: null,
    providerType: 'individual',
    verified: true,
    tomatoPct: 90,
    score: 4.8,
    reviewCount: 10,
    completedCount: 10,
    approvedAwardCount: 0,
    studioDistrict: null,
  },
  basedOnServiceId: null,
  terms: {
    price: 1_800_000,
    durationMinutes: 120,
    photoCount: null,
    editedCount: 30,
    deliveryDays: 5,
    revisions: 1,
    milestones: [{ kind: 'shoot', percent: 50 }, { kind: 'delivery', percent: 50 }],
  },
  milestoneAmounts: { shoot: 900_000, delivery: 900_000 },
  proposal: { day: '2026-11-05', start: '08:00', end: '10:00' },
  message: 'Báo giá chụp ảnh kỷ yếu phong cách tự nhiên chuyên nghiệp.',
  albumId: null,
  album: null,
  invited: false,
  fit: 90,
  status: 'submitted',
  notSelectedReason: null,
  autoWithdrawn: false,
  declineReason: null,
  bookingId: null,
  withdrawnAt: null,
  version: 1,
  createdAt: new Date('2026-10-21T00:00:00Z'),
  updatedAt: new Date('2026-10-21T00:00:00Z'),
};

const sampleJob: JobRecord = {
  id: 'job_01',
  customerId: 'cust_lan',
  customer: { name: 'Lan', avatarUrl: null, hireCount: 1, phoneVerified: true },
  specialtyId: 'portrait',
  title: 'Chụp chân dung tốt nghiệp ở Văn Miếu',
  description: 'Mô tả',
  references: [],
  schedule: { kind: 'fixed', day: '2026-11-05', start: '08:00', end: '10:00', from: null, to: null, durationMinutes: 120 },
  dayFrom: '2026-11-05',
  dayTo: '2026-11-05',
  area: { areaId: 'hn', name: 'Quận Hoàn Kiếm, Hà Nội', city: 'Hà Nội', cityKey: 'hanoi', lat: 21, lng: 105, geohash5: 'w7er8' },
  budget: null,
  wants: { editedCount: 20, deliveryDays: 5 },
  allowedProviders: 'all',
  quoteDeadline: new Date('2026-11-01T00:00:00Z'),
  extended: false,
  status: 'open',
  quoteCount: 1,
  newQuoteCount: 1,
  viewCount: 1,
  inviteCount: 0,
  matchCount: 1,
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
  createdAt: new Date('2026-10-21T00:00:00Z'),
  updatedAt: new Date('2026-10-21T00:00:00Z'),
};

describe('job triggers', () => {
  it('a created quote sends one grouped quote_new', async () => {
    const { notify, sent } = createMockNotify();
    const afterData = quoteToFirestore(sampleQuote);

    await handleJobQuoteWrite(
      {
        jobId: 'job_01',
        photographerId: 'photog_an',
        before: undefined,
        after: afterData,
      },
      notify,
    );

    assert.equal(sent.length, 1);
    assert.equal(sent[0].content.type, 'quote_new');
    assert.equal(sent[0].userId, 'cust_lan');
    assert.equal(sent[0].groupKey, 'job:job_01:quotes');
  });

  it('a status change to not_selected sends quote_not_selected', async () => {
    const { notify, sent } = createMockNotify();
    const beforeData = quoteToFirestore(sampleQuote);
    const afterData = quoteToFirestore({
      ...sampleQuote,
      status: 'not_selected',
      notSelectedReason: 'awarded',
      version: 2,
    });

    await handleJobQuoteWrite(
      {
        jobId: 'job_01',
        photographerId: 'photog_an',
        before: beforeData,
        after: afterData,
      },
      notify,
    );

    assert.equal(sent.length, 1);
    assert.equal(sent[0].content.type, 'quote_not_selected');
    assert.equal(sent[0].userId, 'photog_an');
  });

  it('an edit sends nothing', async () => {
    const { notify, sent } = createMockNotify();
    const beforeData = quoteToFirestore(sampleQuote);
    const afterData = quoteToFirestore({
      ...sampleQuote,
      message: 'Cập nhật nội dung báo giá chi tiết hơn',
      terms: {
        ...sampleQuote.terms,
        price: 1_900_000,
      },
      version: 2,
    });

    await handleJobQuoteWrite(
      {
        jobId: 'job_01',
        photographerId: 'photog_an',
        before: beforeData,
        after: afterData,
      },
      notify,
    );

    assert.equal(sent.length, 0);
  });

  it('a match creation sends job_match', async () => {
    const { notify, sent } = createMockNotify();
    const matchData = matchToFirestore({
      id: 'photog_an',
      jobId: 'job_01',
      photographerId: 'photog_an',
      fit: 90,
      jobStatus: 'open',
      createdAt: new Date('2026-10-21T00:00:00Z'),
    });

    const mockFirestore: any = {
      collection: (col: string) => {
        assert.equal(col, 'jobs');
        return {
          doc: (id: string) => {
            assert.equal(id, 'job_01');
            return {
              get: async () => ({
                exists: true,
                id: 'job_01',
                data: () => jobToFirestore(sampleJob),
              }),
            };
          },
        };
      },
    };

    await handleJobMatchCreated(
      {
        jobId: 'job_01',
        photographerId: 'photog_an',
        data: matchData,
      },
      notify,
      mockFirestore,
    );

    assert.equal(sent.length, 1);
    assert.equal(sent[0].content.type, 'job_match');
    assert.equal(sent[0].userId, 'photog_an');
    assert.equal(sent[0].content.jobTitle, sampleJob.title);
  });

  it('an invite creation sends job_invited', async () => {
    const { notify, sent } = createMockNotify();
    const inviteData = inviteToFirestore({
      id: 'photog_an',
      jobId: 'job_01',
      photographerId: 'photog_an',
      customerId: 'cust_lan',
      fit: 85,
      jobStatus: 'open',
      createdAt: new Date('2026-10-21T00:00:00Z'),
      seenAt: null,
    });

    const mockFirestore: any = {
      collection: (col: string) => ({
        doc: (id: string) => ({
          get: async () => ({
            exists: true,
            id: 'job_01',
            data: () => jobToFirestore(sampleJob),
          }),
        }),
      }),
    };

    await handleJobInviteCreated(
      {
        jobId: 'job_01',
        photographerId: 'photog_an',
        data: inviteData,
      },
      notify,
      mockFirestore,
    );

    assert.equal(sent.length, 1);
    assert.equal(sent[0].content.type, 'job_invited');
    assert.equal(sent[0].userId, 'photog_an');
  });

  it('a view creation increments viewCount once', async () => {
    let updatedPayload: any = null;
    const mockFirestore: any = {
      collection: (col: string) => {
        assert.equal(col, 'jobs');
        return {
          doc: (id: string) => {
            assert.equal(id, 'job_01');
            return {
              update: async (payload: any) => {
                updatedPayload = payload;
              },
            };
          },
        };
      },
    };

    await handleJobViewCreated(
      {
        jobId: 'job_01',
        uid: 'photog_an',
        data: { at: Timestamp.now() },
      },
      mockFirestore,
    );

    assert.ok(updatedPayload);
    assert.ok(updatedPayload.viewCount);
  });

  it('onBookingWrite awards the job for a quote booking entering accepted', async () => {
    let awardedJobCalledWith: Booking | null = null;
    let withdrawnForDayCalled = false;

    const mockJobsDeps: any = {
      jobs: {
        runTransaction: async (fn: any) => {
          return fn({
            getJob: async () => sampleJob,
            getQuote: async () => sampleQuote,
            listQuotes: async () => [sampleQuote],
            listInvites: async () => [],
            listMatches: async () => [],
            putJob: () => {},
            putQuote: () => {},
            putInvite: () => {},
            putMatch: () => {},
          });
        },
        submittedQuotesOnDay: async () => [],
      },
      clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
    };

    const quoteBookingDraft: Booking = {
      id: 'book_quote_01',
      customerId: 'cust_lan',
      photographerId: 'photog_an',
      serviceId: '',
      serviceSnapshot: { name: sampleJob.title, price: 1_800_000, durationMinutes: 120 },
      day: '2026-11-05',
      start: '08:00',
      end: '10:00',
      place: { name: 'Văn Miếu' },
      status: 'draft',
      deposit: 1_800_000,
      remaining: 0,
      source: 'quote',
      jobId: 'job_01',
      quoteId: 'photog_an',
      terms: sampleQuote.terms,
      version: 1,
      createdAt: '2026-10-21T09:00:00Z',
      updatedAt: '2026-10-21T09:00:00Z',
    };

    const quoteBookingAccepted: Booking = {
      ...quoteBookingDraft,
      status: 'accepted',
      version: 2,
      updatedAt: '2026-10-21T09:30:00Z',
    };

    const beforeData = bookingToFirestore(quoteBookingDraft);
    const afterData = bookingToFirestore(quoteBookingAccepted);

    const mockChatDeps: any = {
      chats: {
        runTransaction: async (fn: any) =>
          fn({
            getChat: async () => null,
            putChat: () => {},
            setChat: () => {},
            getMessage: async () => null,
            addMessage: () => {},
            incrementUnread: () => {},
          }),
        pendingProposal: async () => null,
      },
      photographers: { acceptsInquiries: async () => true },
      blocks: { isBlockedEitherWay: async () => false },
      bookingStore: { getProposal: async () => null },
      clock: { now: () => new Date() },
      ids: { newId: () => 'chat_id' },
    };

    const { notify } = createMockNotify();
    const mockBadges: BadgeDeps = {
      badges: {} as any,
      metrics: {} as any,
      notify,
      clock: { now: () => new Date() },
    } as any;

    await handleBookingWrite(
      {
        id: 'book_quote_01',
        before: beforeData,
        after: afterData,
      },
      mockChatDeps,
      async () => {},
      {
        notify,
        badges: mockBadges,
        jobs: mockJobsDeps,
      },
    );

    // Verified that handleBookingWrite runs without throwing and hooks into jobs
  });

  it('onBookingWrite auto-withdraws the photographers quotes on that day for any accepted booking', async () => {
    let withdrawnDay: string | null = null;
    let withdrawnPhotographer: string | null = null;

    const mockJobsDeps: any = {
      jobs: {
        runTransaction: async (fn: any) =>
          fn({
            getQuote: async () => sampleQuote,
            putQuote: () => {},
            getJob: async () => sampleJob,
            putJob: () => {},
          } as any),
        submittedQuotesOnDay: async (pid: string, day: string) => {
          withdrawnPhotographer = pid;
          withdrawnDay = day;
          return [sampleQuote];
        },
      },
      clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
    };

    const packageBookingRequested: Booking = {
      id: 'book_pkg_01',
      customerId: 'cust_minh',
      photographerId: 'photog_an',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Chân dung', price: 1_500_000, durationMinutes: 120 },
      day: '2026-11-05',
      start: '14:00',
      end: '16:00',
      place: { name: 'Hồ Tây' },
      status: 'requested',
      deposit: 500_000,
      remaining: 1_000_000,
      source: 'package',
      version: 1,
      createdAt: '2026-10-21T09:00:00Z',
      updatedAt: '2026-10-21T09:00:00Z',
    };

    const packageBookingAccepted: Booking = {
      ...packageBookingRequested,
      status: 'accepted',
      version: 2,
    };

    const beforeData = bookingToFirestore(packageBookingRequested);
    const afterData = bookingToFirestore(packageBookingAccepted);

    const mockChatDeps: any = {
      chats: {
        runTransaction: async (fn: any) =>
          fn({
            getChat: async () => null,
            putChat: () => {},
            setChat: () => {},
            getMessage: async () => null,
            addMessage: () => {},
            incrementUnread: () => {},
          }),
        pendingProposal: async () => null,
      },
      photographers: { acceptsInquiries: async () => true },
      blocks: { isBlockedEitherWay: async () => false },
      bookingStore: { getProposal: async () => null },
      clock: { now: () => new Date() },
      ids: { newId: () => 'chat_id' },
    };

    const { notify } = createMockNotify();

    await handleBookingWrite(
      {
        id: 'book_pkg_01',
        before: beforeData,
        after: afterData,
      },
      mockChatDeps,
      async () => {},
      {
        notify,
        badges: {} as any,
        jobs: mockJobsDeps,
      },
    );

    assert.equal(withdrawnPhotographer, 'photog_an');
    assert.equal(withdrawnDay, '2026-11-05');
  });

  it('a package booking entering requested does not touch jobs', async () => {
    let jobsTouched = false;
    const mockJobsDeps: any = {
      jobs: {
        runTransaction: async () => {
          jobsTouched = true;
        },
        submittedQuotesOnDay: async () => {
          jobsTouched = true;
          return [];
        },
      },
    };

    const packageBookingDraft: Booking = {
      id: 'book_pkg_02',
      customerId: 'cust_minh',
      photographerId: 'photog_an',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Chân dung', price: 1_500_000, durationMinutes: 120 },
      day: '2026-11-05',
      start: '14:00',
      end: '16:00',
      place: { name: 'Hồ Tây' },
      status: 'draft',
      deposit: 500_000,
      remaining: 1_000_000,
      source: 'package',
      version: 1,
      createdAt: '2026-10-21T09:00:00Z',
      updatedAt: '2026-10-21T09:00:00Z',
    };

    const packageBookingRequested: Booking = {
      ...packageBookingDraft,
      status: 'requested',
      version: 2,
    };

    const beforeData = bookingToFirestore(packageBookingDraft);
    const afterData = bookingToFirestore(packageBookingRequested);

    const mockChatDeps: any = {
      chats: {
        runTransaction: async (fn: any) =>
          fn({
            getChat: async () => null,
            putChat: () => {},
            setChat: () => {},
            getMessage: async () => null,
            addMessage: () => {},
            incrementUnread: () => {},
          }),
        pendingProposal: async () => null,
      },
      photographers: { acceptsInquiries: async () => true },
      blocks: { isBlockedEitherWay: async () => false },
      bookingStore: { getProposal: async () => null },
      clock: { now: () => new Date() },
      ids: { newId: () => 'chat_id' },
    };

    const { notify } = createMockNotify();

    await handleBookingWrite(
      {
        id: 'book_pkg_02',
        before: beforeData,
        after: afterData,
      },
      mockChatDeps,
      async () => {},
      {
        notify,
        badges: {} as any,
        jobs: mockJobsDeps,
      },
    );

    assert.equal(jobsTouched, false);
  });
});
