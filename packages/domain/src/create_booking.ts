/**
 * Use case: createBookingDraft
 * Customer creates a draft booking, holding the photographer's day as pending.
 */

import type { Booking } from './booking.js';
import { addMinutesToTime, computeDeposit } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { validateCreateBookingDraftInput } from './booking_requests.js';
import { DomainError } from './errors.js';
import { requireCustomerPhone } from './require_phone.js';

export async function createBookingDraft(
  deps: BookingDeps,
  rawInput: unknown,
): Promise<Booking> {
  const now = deps.clock.now();
  const input = validateCreateBookingDraftInput(rawInput, now);

  // 1. Service check
  const service = await deps.services.getService(input.serviceId);
  if (!service || !service.active || service.photographerId !== input.photographerId) {
    throw new DomainError('not_found');
  }

  if (input.expectedPrice !== undefined && input.expectedPrice !== service.price) {
    throw new DomainError('price_changed');
  }

  // 2. Phone requirement check (server enforced)
  const phone = await requireCustomerPhone(deps.contacts, input.customerId);
  const contactRecord = await deps.contacts.get(input.customerId);

  // 3. Financial calculations
  const { deposit, remaining } = computeDeposit(service.price);
  const end = addMinutesToTime(input.start, service.durationMinutes);

  // 4. Transactional availability hold and booking creation
  return deps.store.runTransaction(async (tx) => {
    const existingDay = await tx.getAvailabilityDay(input.photographerId, input.day);
    const existingDraft = await tx.getCustomerDraftForDay(
      input.customerId,
      input.photographerId,
      input.day,
    );

    if (existingDay) {
      if (existingDay.state === 'off' || existingDay.state === 'booked') {
        throw new DomainError('day_taken');
      }
      if (existingDay.state === 'pending') {
        // Allowed only if it is the same customer's own earlier draft (Review Focus 2)
        const isOwnDraft = existingDraft && existingDay.bookingId === existingDraft.id;
        if (!isOwnDraft) {
          throw new DomainError('day_taken');
        }
      }
    }

    // Replace customer's earlier draft if present
    if (existingDraft) {
      await tx.deleteBooking(existingDraft.id);
      await tx.deleteContactSnapshot(existingDraft.id);
    }

    const bookingId = deps.ids.newId();
    const createdAt = now.toISOString();

    const booking: Booking = {
      id: bookingId,
      customerId: input.customerId,
      photographerId: input.photographerId,
      serviceId: input.serviceId,
      serviceSnapshot: {
        name: service.name,
        price: service.price,
        durationMinutes: service.durationMinutes,
      },
      day: input.day,
      start: input.start,
      end,
      place: input.place,
      note: input.note,
      status: 'draft',
      deposit,
      remaining,
      version: 1,
      createdAt,
      updatedAt: createdAt,
    };

    await tx.setBooking(booking);
    await tx.setAvailabilityDay(input.photographerId, input.day, {
      state: 'pending',
      bookingId,
    });
    await tx.setContactSnapshot(bookingId, {
      name: contactRecord?.name ?? '',
      phone,
      allowZalo: contactRecord?.allowZalo ?? false,
      allowWhatsApp: contactRecord?.allowWhatsApp ?? false,
    });

    return booking;
  });
}
