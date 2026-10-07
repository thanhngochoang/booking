/**
 * VietQR (EMVCo merchant-presented QR, NAPAS 247 transfer to an account) payload builder.
 * Pure string maths, no dependencies.
 */

/** CRC-16/CCITT-FALSE: polynomial 0x1021, init 0xFFFF, no reflection, no final xor. */
export function crc16Ccitt(input: string): string {
  let crc = 0xffff;
  for (const byte of new TextEncoder().encode(input)) {
    crc ^= byte << 8;
    for (let bit = 0; bit < 8; bit++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

/** One TLV field: tag, two-digit zero-padded length in characters, value. */
function tlv(tag: string, value: string): string {
  if (value.length > 99) {
    throw new RangeError(`VietQR field ${tag} is longer than 99 characters`);
  }
  return `${tag}${String(value.length).padStart(2, '0')}${value}`;
}

/**
 * The text encoded in the QR image for a transfer of `amount` VND to `accountNumber` at the bank
 * with NAPAS BIN `bin`, with `content` as the transfer memo (field 62/08).
 */
export function buildVietQrPayload(p: {
  readonly bin: string;
  readonly accountNumber: string;
  readonly amount: number;
  readonly content: string;
}): string {
  if (!Number.isInteger(p.amount) || p.amount <= 0) {
    throw new RangeError('VietQR amount must be a positive integer VND');
  }
  const beneficiary = tlv('00', p.bin) + tlv('01', p.accountNumber);
  const merchant = tlv('00', 'A000000727') + tlv('01', beneficiary) + tlv('02', 'QRIBFTTA');
  const body =
    tlv('00', '01') +
    tlv('01', '12') +
    tlv('38', merchant) +
    tlv('53', '704') +
    tlv('54', String(p.amount)) +
    tlv('58', 'VN') +
    tlv('62', tlv('08', p.content)) +
    '6304';
  return body + crc16Ccitt(body);
}
