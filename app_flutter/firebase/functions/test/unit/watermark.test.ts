import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import {
  loadWatermarkFont,
  watermarkSvg,
  watermarkSample,
  SAMPLE_LONG_SIDE,
  THUMB_LONG_SIDE,
} from '../../src/infra/watermark.js';

describe('watermark infra', () => {
  const font = loadWatermarkFont();

  it('watermarkSample shrinks the long side to 1600 and keeps the aspect', async () => {
    const input = await sharp({
      create: {
        width: 3000,
        height: 2000,
        channels: 3,
        background: { r: 120, g: 170, b: 170 },
      },
    })
      .jpeg()
      .toBuffer();

    const result = await watermarkSample(input, 'Nguyễn Văn An · Bản xem trước', font);
    assert.equal(result.width, SAMPLE_LONG_SIDE);
    assert.equal(result.height, Math.round((2000 / 3000) * SAMPLE_LONG_SIDE));

    const meta = await sharp(result.sample).metadata();
    assert.equal(meta.width, SAMPLE_LONG_SIDE);
    assert.equal(meta.height, Math.round((2000 / 3000) * SAMPLE_LONG_SIDE));
    assert.equal(meta.format, 'jpeg');
  });

  it('a 1200 px image is not enlarged', async () => {
    const input = await sharp({
      create: {
        width: 1200,
        height: 800,
        channels: 3,
        background: '#7aa',
      },
    })
      .jpeg()
      .toBuffer();

    const result = await watermarkSample(input, 'Nguyễn Văn An · Bản xem trước', font);
    assert.equal(result.width, 1200);
    assert.equal(result.height, 800);
  });

  it('the output has no EXIF', async () => {
    const input = await sharp({
      create: {
        width: 2000,
        height: 1500,
        channels: 3,
        background: '#7aa',
      },
    })
      .withMetadata({
        exif: {
          IFD0: {
            Copyright: 'Secret Copyright',
            Artist: 'Secret Artist',
          },
        },
      })
      .jpeg()
      .toBuffer();

    const result = await watermarkSample(input, 'Nguyễn Văn An · Bản xem trước', font);
    const meta = await sharp(result.sample).metadata();
    assert.equal(meta.exif, undefined);
  });

  it('the thumbnail long side is 400', async () => {
    const input = await sharp({
      create: {
        width: 2400,
        height: 1600,
        channels: 3,
        background: '#7aa',
      },
    })
      .jpeg()
      .toBuffer();

    const result = await watermarkSample(input, 'Nhiếp ảnh gia · Bản xem trước', font);
    const thumbMeta = await sharp(result.thumb).metadata();
    assert.equal(thumbMeta.width, THUMB_LONG_SIDE);
    assert.equal(thumbMeta.height, Math.round((1600 / 2400) * THUMB_LONG_SIDE));
    assert.equal(thumbMeta.format, 'jpeg');
  });

  it('the watermark changes the pixels', async () => {
    const input = await sharp({
      create: {
        width: 1600,
        height: 1200,
        channels: 3,
        background: { r: 50, g: 50, b: 50 },
      },
    })
      .jpeg()
      .toBuffer();

    const plain = await sharp(input)
      .resize({ width: 1600, height: 1200, fit: 'inside' })
      .raw()
      .toBuffer();

    const result = await watermarkSample(input, 'Nguyễn Văn An · Bản xem trước', font);
    const watermarkedRaw = await sharp(result.sample)
      .resize({ width: 1600, height: 1200 })
      .raw()
      .toBuffer();

    let diffSum = 0;
    // Calculate mean absolute difference in the center region
    const centerStart = Math.floor(plain.length * 0.4);
    const centerEnd = Math.floor(plain.length * 0.6);
    for (let i = centerStart; i < centerEnd; i++) {
      diffSum += Math.abs((plain[i] ?? 0) - (watermarkedRaw[i] ?? 0));
    }
    const meanDiff = diffSum / (centerEnd - centerStart);
    assert.ok(meanDiff > 1, `Expected mean pixel difference > 1, got ${meanDiff}`);
  });

  it('watermarkSvg tiles the label across the whole image', () => {
    const svg = watermarkSvg(1600, 1067, 'Nguyễn Văn An · Bản xem trước', font);
    const useMatches = svg.match(/<use /g);
    assert.ok(useMatches !== null && useMatches.length >= 6);
  });

  it('Vietnamese diacritics are drawn', () => {
    const pathWithDiacritics = font.getPath('Trí · Bản xem trước', 0, 0, 30).toPathData(1);
    const pathWithoutDiacritics = font.getPath('Tri . Ban xem truoc', 0, 0, 30).toPathData(1);
    assert.ok(pathWithDiacritics.length > pathWithoutDiacritics.length);
  });
});
