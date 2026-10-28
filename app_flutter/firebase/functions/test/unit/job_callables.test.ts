/* eslint-disable @typescript-eslint/no-explicit-any */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  type JobDeps,
  type BookingDeps,
  type ChatDeps,
  type JobRecord,
  type QuoteRecord,
} from '@photobooking/domain';
import {
  handleCreateJob,
  handleUpdateJob,
  handleExtendJob,
  handleCloseJob,
  handleInviteToJob,
  handleSubmitQuote,
  handleWithdrawQuote,
  handleDeclineQuote,
  handleAcceptQuote,
  handleOpenJobInquiry,
} from '../../src/callables/job.js';

function createMockJobDeps(overrides: Partial<JobDeps> = {}): JobDeps {
  return {
    jobs: {
      runTransaction: async (fn) => fn({} as any),
      countOpenJobs: async () => 0,
      countSubmittedQuotes: async () => 0,
      submittedQuotesOnDay: async () => [],
      dueForExpiry: async () => [],
      dueForExpiringNotice: async () => [],
      dueForReferencePurge: async () => [],
    },
    people: {
      customer: async () => ({
        role: 'customer',
        name: 'Lan',
        avatarUrl: null,
        phoneVerified: true,
        hireCount: 1,
      }),
      provider: async (uid) => ({
        uid,
        role: 'photographer',
        onboardingComplete: true,
        acceptingOrdersFields: { verified: true, onboardingComplete: true },
        providerType: 'individual',
        specialties: ['portrait'],
        serviceArea: { city: 'Hà Nội', radiusKm: 30, center: null },
        startingPrice: 1_000_000,
        tomatoPct: 90,
        score: 4.5,
        reviewCount: 10,
        completedCount: 10,
        approvedAwardCount: 0,
        verified: true,
        name: 'An',
        avatarUrl: null,
        studioDistrict: null,
      }),
      candidates: async () => [],
      dayState: async () => 'free',
      dayBookingId: async () => null,
      service: async () => null,
      album: async () => null,
    },
    contacts: {
      get: async () => ({ phone: '+84900000001' }),
    },
    media: {
      isOwnReference: () => true,
      deleteReference: async () => {},
    },
    providers: {
      acceptsOrders: async () => true,
    },
    blocks: {
      isBlockedEitherWay: async () => false,
    },
    clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
    ids: { newId: () => '01ARZ3NDEKTSV4RRFFQ69G5F01' },
    ...overrides,
  };
}

describe('job callables', () => {
  it('unauthenticated is permission_denied for all callables', async () => {
    const deps = createMockJobDeps();
    const req = { data: {}, auth: undefined };

    await assert.rejects(async () => handleCreateJob(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      assert.equal(err.message, 'permission_denied');
      return true;
    });

    await assert.rejects(async () => handleUpdateJob(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleExtendJob(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleCloseJob(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleInviteToJob(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleSubmitQuote(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleWithdrawQuote(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleDeclineQuote(req as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleAcceptQuote(req as any, deps, {} as any), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });

    await assert.rejects(async () => handleOpenJobInquiry(req as any, {} as any, deps), (err: any) => {
      assert.equal(err.code, 'unauthenticated');
      return true;
    });
  });

  it('createJob passes the uid and returns jobId and matched', async () => {
    const deps = createMockJobDeps({
      jobs: {
        runTransaction: async (fn: any) => {
          return fn({
            getJob: async () => null,
            getQuote: async () => null,
            getInvite: async () => null,
            listQuotes: async () => [],
            listInvites: async () => [],
            listMatches: async () => [],
            putJob: () => {},
            putQuote: () => {},
            putInvite: () => {},
            putMatch: () => {},
          });
        },
        countOpenJobs: async () => 0,
        countSubmittedQuotes: async () => 0,
        submittedQuotesOnDay: async () => [],
        dueForExpiry: async () => [],
        dueForExpiringNotice: async () => [],
        dueForReferencePurge: async () => [],
      },
      people: {
        customer: async () => ({
          role: 'customer',
          name: 'Lan',
          avatarUrl: null,
          phoneVerified: true,
          hireCount: 1,
        }),
        provider: async () => null,
        candidates: async () => [],
        dayState: async () => 'free',
        dayBookingId: async () => null,
        service: async () => null,
        album: async () => null,
      },
      ids: { newId: () => '01ARZ3NDEKTSV4RRFFQ69G5F01' },
    });

    const res = await handleCreateJob(
      {
        auth: { uid: 'cust_lan' },
        data: {
          specialtyId: 'portrait',
          title: 'Chụp chân dung tốt nghiệp',
          description: 'Cần tìm thợ chụp kỷ yếu tại Văn Miếu',
          references: [],
          schedule: {
            kind: 'fixed',
            day: '2026-11-01',
            start: '08:00',
            end: '10:00',
            durationMinutes: 120,
          },
          area: {
            areaId: 'hn-hoan-kiem',
            name: 'Quận Hoàn Kiếm, Hà Nội',
            lat: 21.0285,
            lng: 105.8542,
          },
          budget: { min: 1_000_000, max: 2_000_000 },
          wants: { editedCount: 30, deliveryDays: 7 },
          allowedProviders: 'all',
          deadlineDays: 3,
        },
      } as any,
      deps,
    );

    assert.equal(res.jobId, '01ARZ3NDEKTSV4RRFFQ69G5F01');
    assert.equal(typeof res.matched, 'number');
  });

  it('a domain field error carries details.field', async () => {
    const deps = createMockJobDeps();

    await assert.rejects(
      async () =>
        handleCreateJob(
          {
            auth: { uid: 'cust_lan' },
            data: {
              specialtyId: 'portrait',
              title: 'Ngắn', // < 10 characters -> invalid_argument, field: title
              description: 'Mô tả',
              references: [],
              schedule: {
                kind: 'fixed',
                day: '2026-11-01',
                start: '08:00',
                end: '10:00',
              },
              area: { areaId: 'hn-hoan-kiem', name: 'Hoàn Kiếm, Hà Nội', lat: 21, lng: 105 },
              allowedProviders: 'all',
              deadlineDays: 3,
            },
          } as any,
          deps,
        ),
      (err: any) => {
        assert.equal(err.code, 'invalid-argument');
        assert.equal(err.details?.field, 'title');
        return true;
      },
    );
  });

  it('submitQuote refuses a closed provider with failed-precondition and details.code not_accepting_orders', async () => {
    const deps = createMockJobDeps({
      jobs: {
        runTransaction: async (fn: any) => {
          return fn({
            getJob: async () => ({
              id: '01ARZ3NDEKTSV4RRFFQ69G5F01',
              customerId: 'cust_lan',
              status: 'open',
              quoteDeadline: new Date('2026-11-01T00:00:00Z'),
              schedule: { kind: 'fixed', day: '2026-11-05', start: '08:00', end: '10:00', durationMinutes: 120 },
              area: { areaId: 'hn', name: 'Hà Nội', city: 'Hà Nội', cityKey: 'hanoi', lat: 21, lng: 105, geohash5: 'w7er8' },
              allowedProviders: 'all',
            } as any),
            getQuote: async () => null,
            getInvite: async () => null,
            listQuotes: async () => [],
            listInvites: async () => [],
            listMatches: async () => [],
            putJob: () => {},
            putQuote: () => {},
            putInvite: () => {},
            putMatch: () => {},
          });
        },
        countOpenJobs: async () => 0,
        countSubmittedQuotes: async () => 0,
        submittedQuotesOnDay: async () => [],
        dueForExpiry: async () => [],
        dueForExpiringNotice: async () => [],
        dueForReferencePurge: async () => [],
      },
      providers: {
        acceptsOrders: async () => false,
      },
    });

    await assert.rejects(
      async () =>
        handleSubmitQuote(
          {
            auth: { uid: 'photog_closed' },
            data: {
              jobId: '01ARZ3NDEKTSV4RRFFQ69G5F01',
              price: 1_500_000,
              editedCount: 20,
              deliveryDays: 5,
              revisions: 1,
              message: 'Báo giá chụp ảnh kỷ yếu phong cách tự nhiên chuyên nghiệp.',
            },
          } as any,
          deps,
        ),
      (err: any) => {
        assert.equal(err.code, 'failed-precondition');
        assert.equal(err.details?.code, 'not_accepting_orders');
        return true;
      },
    );
  });

  it('submitQuote refuses a blocked pair with failed-precondition and details.code blocked', async () => {
    const deps = createMockJobDeps({
      jobs: {
        runTransaction: async (fn: any) => {
          return fn({
            getJob: async () => ({
              id: '01ARZ3NDEKTSV4RRFFQ69G5F01',
              customerId: 'cust_lan',
              status: 'open',
              quoteDeadline: new Date('2026-11-01T00:00:00Z'),
              schedule: { kind: 'fixed', day: '2026-11-05', start: '08:00', end: '10:00', durationMinutes: 120 },
              area: { areaId: 'hn', name: 'Hà Nội', city: 'Hà Nội', cityKey: 'hanoi', lat: 21, lng: 105, geohash5: 'w7er8' },
              allowedProviders: 'all',
            } as any),
            getQuote: async () => null,
            getInvite: async () => null,
            listQuotes: async () => [],
            listInvites: async () => [],
            listMatches: async () => [],
            putJob: () => {},
            putQuote: () => {},
            putInvite: () => {},
            putMatch: () => {},
          });
        },
        countOpenJobs: async () => 0,
        countSubmittedQuotes: async () => 0,
        submittedQuotesOnDay: async () => [],
        dueForExpiry: async () => [],
        dueForExpiringNotice: async () => [],
        dueForReferencePurge: async () => [],
      },
      people: {
        customer: async () => null,
        provider: async (uid) => ({
          uid,
          role: 'photographer',
          onboardingComplete: true,
          acceptingOrdersFields: { verified: true, onboardingComplete: true },
          providerType: 'individual',
          specialties: ['portrait'],
          serviceArea: { city: 'Hà Nội', radiusKm: 30, center: null },
          startingPrice: 1_000_000,
          tomatoPct: 90,
          score: 4.5,
          reviewCount: 10,
          completedCount: 10,
          approvedAwardCount: 0,
          verified: true,
          name: 'An',
          avatarUrl: null,
          studioDistrict: null,
        }),
        candidates: async () => [],
        dayState: async () => 'free',
        dayBookingId: async () => null,
        service: async () => null,
        album: async () => null,
      },
      blocks: {
        isBlockedEitherWay: async () => true,
      },
    });

    await assert.rejects(
      async () =>
        handleSubmitQuote(
          {
            auth: { uid: 'photog_blocked' },
            data: {
              jobId: '01ARZ3NDEKTSV4RRFFQ69G5F01',
              price: 1_500_000,
              editedCount: 20,
              deliveryDays: 5,
              revisions: 1,
              message: 'Báo giá chụp ảnh kỷ yếu phong cách tự nhiên chuyên nghiệp.',
            },
          } as any,
          deps,
        ),
      (err: any) => {
        assert.equal(err.code, 'failed-precondition');
        assert.equal(err.details?.code, 'blocked');
        return true;
      },
    );
  });

  it('acceptQuote returns bookingId, paymentId and #129s checkout', async () => {
    const job: JobRecord = {
      id: '01ARZ3NDEKTSV4RRFFQ69G5F01',
      customerId: 'cust_lan',
      customer: { name: 'Lan', avatarUrl: null, hireCount: 1, phoneVerified: true },
      specialtyId: 'portrait',
      title: 'Chụp chân dung tốt nghiệp',
      description: 'Mô tả',
      references: [],
      schedule: { kind: 'fixed', day: '2026-11-05', start: '08:00', end: '10:00', from: null, to: null, durationMinutes: 120 },
      dayFrom: '2026-11-05',
      dayTo: '2026-11-05',
      area: { areaId: 'hn', name: 'Hà Nội', city: 'Hà Nội', cityKey: 'hanoi', lat: 21, lng: 105, geohash5: 'w7er8' },
      budget: null,
      wants: { editedCount: 20, deliveryDays: 5 },
      allowedProviders: 'all',
      quoteDeadline: new Date('2026-11-01T00:00:00Z'),
      extended: false,
      status: 'open',
      quoteCount: 1,
      newQuoteCount: 0,
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

    const quote: QuoteRecord = {
      id: 'photog_an',
      jobId: '01ARZ3NDEKTSV4RRFFQ69G5F01',
      photographerId: 'photog_an',
      customerId: 'cust_lan',
      jobTitle: 'Chụp chân dung tốt nghiệp',
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

    const deps = createMockJobDeps({
      jobs: {
        runTransaction: async (fn: any) => {
          return fn({
            getJob: async () => job,
            getQuote: async () => quote,
            getInvite: async () => null,
            listQuotes: async () => [quote],
            listInvites: async () => [],
            listMatches: async () => [],
            putJob: () => {},
            putQuote: () => {},
            putInvite: () => {},
            putMatch: () => {},
          });
        },
        countOpenJobs: async () => 0,
        countSubmittedQuotes: async () => 0,
        submittedQuotesOnDay: async () => [],
        dueForExpiry: async () => [],
        dueForExpiringNotice: async () => [],
        dueForReferencePurge: async () => [],
      },
      people: {
        customer: async () => ({ role: 'customer', name: 'Lan', avatarUrl: null, phoneVerified: true, hireCount: 1 }),
        provider: async () => null,
        candidates: async () => [],
        dayState: async () => 'free',
        dayBookingId: async () => null,
        service: async () => null,
        album: async () => null,
      },
    });

    let savedBooking: any = null;
    let availabilityDay: any = null;
    const bookingDeps: BookingDeps = ({
      store: {
        runTransaction: async (fn: any) => {
          return fn({
            getBooking: async () => savedBooking,
            setBooking: async (b: any) => { savedBooking = b; },
            deleteBooking: async () => {},
            getAvailability: async () => null,
            setAvailability: async () => {},
            getPayment: async () => null,
            setPayment: async () => {},
            addLedgerEntry: async () => {},
            findActiveBookingsForCustomerOnDay: async () => [],
            setContactSnapshot: async () => {},
            getAvailabilityDay: async () => availabilityDay,
            setAvailabilityDay: async (_p: any, _d: any, day: any) => { availabilityDay = day; },
            addBookingEvent: async () => {},
          } as any);
        },
        getBooking: async () => savedBooking,
        getPaymentsForBooking: async () => [],
        findPaymentsByTransferCode: async () => [],
        getAvailabilityDay: async () => availabilityDay,
        findActiveBookingsForCustomerOnDay: async () => [],
        findExpiredDrafts: async () => [],
        findDueAutoApproveNotices: async () => [],
        findUpcomingPage: async () => ({ bookings: [], next: null }),
      } as any,
      services: {} as any,
      providers: { acceptsOrders: async () => true } as any,
      contacts: {
        get: async () => ({ phone: '+84900000001' }),
      } as any,
      gateway: {
        createPayment: async () => ({
          paymentId: 'pay_123',
          checkout: {
            method: 'bank_qr',
            amount: 1_800_000,
            qrPayload: '000201...',
            transferCode: 'PB123456',
            expiresAt: '2026-10-21T10:30:00.000Z',
          },
        }),
      } as any,
      clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
      ids: (() => {
        let n = 0;
        return { newId: () => (n++ === 0 ? 'booking_created_01' : 'pay_123') };
      })(),
    } as any);

    const res = await handleAcceptQuote(
      {
        auth: { uid: 'cust_lan' },
        data: {
          jobId: '01ARZ3NDEKTSV4RRFFQ69G5F01',
          photographerId: 'photog_an',
          place: { name: 'Văn Miếu Quốc Tử Giám' },
          method: 'bank_qr',
        },
      } as any,
      deps,
      bookingDeps,
    );

    assert.ok(res.bookingId);
    assert.equal(res.paymentId, 'pay_123');
    assert.equal(res.checkout.method, 'bank_qr');
    assert.equal(res.checkout.amount, 1_800_000);
  });

  it('openJobInquiry returns the chat id', async () => {
    const deps = createMockJobDeps({
      jobs: {
        runTransaction: async (fn: any) => {
          return fn({
            getJob: async () => ({
              id: '01ARZ3NDEKTSV4RRFFQ69G5F01',
              customerId: 'cust_lan',
              status: 'open',
            } as any),
            getQuote: async () => null,
            getInvite: async () => null,
            listQuotes: async () => [],
            listInvites: async () => [],
            listMatches: async () => [],
            putJob: () => {},
            putQuote: () => {},
            putInvite: () => {},
            putMatch: () => {},
          });
        },
        countOpenJobs: async () => 0,
        countSubmittedQuotes: async () => 0,
        submittedQuotesOnDay: async () => [],
        dueForExpiry: async () => [],
        dueForExpiringNotice: async () => [],
        dueForReferencePurge: async () => [],
      },
    });

    const chatDeps: ChatDeps = {
      chats: {
        runTransaction: async (fn: any) => {
          return fn({
            getChat: async () => null,
            setChat: () => {},
            incrementUnread: () => {},
          } as any);
        },
      } as any,
      photographers: {
        acceptsInquiries: async () => true,
      },
      blocks: {
        isBlockedEitherWay: async () => false,
      },
      clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
      ids: { newId: () => 'chat_new_id' },
    };

    const res = await handleOpenJobInquiry(
      {
        auth: { uid: 'photog_an' },
        data: {
          jobId: '01ARZ3NDEKTSV4RRFFQ69G5F01',
        },
      } as any,
      chatDeps,
      deps,
    );

    assert.equal(res.chatId, 'cust_lan_photog_an');
  });
});
