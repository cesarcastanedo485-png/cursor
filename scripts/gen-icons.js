/**
 * Generate PWA icons for Mordecai's Maximus (run: npm run gen-icons)
 * Requires: npm install jimp --save-dev
 */
import { Jimp } from "jimp";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, "..", "public");

async function main() {
  const sizes = [192, 512];
  const bgColor = 0x0d1117ff; // #0d1117
  const accentColor = 0x58a6ffff; // #58a6ff

  for (const size of sizes) {
    const img = new Jimp({ width: size, height: size, color: bgColor });
    const stroke = Math.max(2, Math.floor(size / 64));
    const margin = Math.floor(size * 0.15);
    for (let i = 0; i < stroke; i++) {
      const m = margin + i;
      const end = size - 1 - m;
      for (let x = m; x <= end; x++) {
        img.setPixelColor(accentColor, x, m);
        img.setPixelColor(accentColor, x, end);
      }
      for (let y = m; y <= end; y++) {
        img.setPixelColor(accentColor, m, y);
        img.setPixelColor(accentColor, end, y);
      }
    }
    const out = path.join(publicDir, `icon-${size}.png`);
    await img.write(out);
    console.log(`Created ${out}`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
