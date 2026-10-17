import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import sharp from 'sharp';

export const SAMPLE_LONG_SIDE = 1600;
export const SAMPLE_QUALITY = 75;
export const THUMB_LONG_SIDE = 400;
export const THUMB_QUALITY = 70;
export const WATERMARK_OPACITY = 0.35;
export const MAX_UPLOAD_BYTES = 2 * 1024 * 1024;

let cachedFont: opentype.Font | null = null;

export function loadWatermarkFont(): opentype.Font {
  if (cachedFont) return cachedFont;
  const currentDir = path.dirname(fileURLToPath(import.meta.url));
  // Look for assets/fonts/BeVietnamPro-SemiBold.ttf:
  // 1. Next to dist/lib or src
  const candidates = [
    path.resolve(currentDir, '../../assets/fonts/BeVietnamPro-SemiBold.ttf'),
    path.resolve(currentDir, '../assets/fonts/BeVietnamPro-SemiBold.ttf'),
    path.resolve(process.cwd(), 'assets/fonts/BeVietnamPro-SemiBold.ttf'),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      const buffer = fs.readFileSync(candidate);
      cachedFont = opentype.parse(buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength));
      return cachedFont;
    }
  }

  throw new Error('Watermark font BeVietnamPro-SemiBold.ttf not found in search paths');
}

export function watermarkSvg(w: number, h: number, label: string, font: opentype.Font): string {
  const size = Math.max(14, Math.round(Math.max(w, h) / 28));
  const d = font.getPath(label, 0, 0, size).toPathData(1);
  const stepX = font.getAdvanceWidth(label, size) + size * 3;
  const stepY = size * 4;
  const r = Math.ceil(Math.hypot(w, h) / 2);
  let uses = '';
  for (let y = -r, row = 0; y <= r; y += stepY, row++) {
    for (let x = -r + (row % 2) * (stepX / 2); x <= r; x += stepX) {
      uses += `<use xlink:href="#t" x="${Math.round(x)}" y="${Math.round(y)}"/>`;
    }
  }
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}">` +
    `<defs><path id="t" d="${d}"/></defs>` +
    `<g transform="translate(${w / 2} ${h / 2}) rotate(-32)" fill="#fff" fill-opacity="${WATERMARK_OPACITY}"` +
    ` stroke="#000" stroke-opacity="0.18" stroke-width="${(size / 24).toFixed(2)}">${uses}</g></svg>`
  );
}

export async function watermarkSample(
  input: Buffer,
  label: string,
  font: opentype.Font,
): Promise<{ sample: Buffer; thumb: Buffer; width: number; height: number }> {
  const resized = await sharp(input, { failOn: 'error', limitInputPixels: 50_000_000 })
    .rotate() // apply EXIF orientation; metadata is not copied to the output
    .resize({ width: SAMPLE_LONG_SIDE, height: SAMPLE_LONG_SIDE, fit: 'inside', withoutEnlargement: true })
    .toColourspace('srgb')
    .toBuffer({ resolveWithObject: true });

  const { width, height } = resized.info;
  const sample = await sharp(resized.data)
    .composite([{ input: Buffer.from(watermarkSvg(width, height, label, font)), top: 0, left: 0 }])
    .jpeg({ quality: SAMPLE_QUALITY, mozjpeg: true })
    .toBuffer();

  const thumb = await sharp(sample)
    .resize({ width: THUMB_LONG_SIDE, height: THUMB_LONG_SIDE, fit: 'inside' })
    .jpeg({ quality: THUMB_QUALITY })
    .toBuffer();

  return { sample, thumb, width, height };
}
