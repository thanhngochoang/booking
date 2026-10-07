import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { buildVietQrPayload, crc16Ccitt } from '../src/vietqr.js';

const params = { bin: '970418', accountNumber: '96247000003812', amount: 1_500_000, content: 'PB 7F3K2Q' };

describe('crc16Ccitt', () => {
  it('matches the standard check value', () => {
    assert.equal(crc16Ccitt('123456789'), '29B1');
  });
  it('pads to four upper-case hex digits', () => {
    assert.match(crc16Ccitt(''), /^[0-9A-F]{4}$/);
    assert.equal(crc16Ccitt(''), 'FFFF');
  });
});

describe('buildVietQrPayload', () => {
  it('builds the TLV fields', () => {
    const p = buildVietQrPayload(params);
    assert.ok(p.startsWith('000201010212'), p);
    assert.ok(p.includes('0010A000000727'), p);
    assert.ok(p.includes('0006970418' + '0114' + '96247000003812'), p);
    assert.ok(p.includes('0208QRIBFTTA'), p);
    assert.ok(p.includes('5303704'), p);
    assert.ok(p.includes('54071500000'), p);
    assert.ok(p.includes('5802VN'), p);
    assert.ok(p.includes('62130809PB 7F3K2Q'), p);
    const body = p.slice(0, -4);
    assert.ok(body.endsWith('6304'), p);
    assert.equal(p.slice(-4), crc16Ccitt(body));
  });

  it('nests the beneficiary in field 38 with the right length', () => {
    const p = buildVietQrPayload(params);
    const inner = '0010A000000727' + '0128' + '0006970418' + '011496247000003812' + '0208QRIBFTTA';
    // 0128 = length of the consumer sub-block: 0006970418 (10) + 011496247000003812 (18)
    assert.ok(p.includes(`38${String(inner.length).padStart(2, '0')}${inner}`), p);
  });

  it('a different amount changes the CRC', () => {
    const a = buildVietQrPayload(params);
    const b = buildVietQrPayload({ ...params, amount: 1_500_001 });
    assert.notEqual(a.slice(-4), b.slice(-4));
  });

  it('rejects amounts that are not positive integers and fields that overflow a TLV', () => {
    assert.throws(() => buildVietQrPayload({ ...params, amount: 0 }));
    assert.throws(() => buildVietQrPayload({ ...params, amount: 1.5 }));
    assert.throws(() => buildVietQrPayload({ ...params, content: 'x'.repeat(100) }));
  });
});
