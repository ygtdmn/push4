import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { varyColor, hexToRgb, rgbToHex, clamp } from "./utils";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PIXELS_FILE = path.join(__dirname, "./data/pixel-data.json");
const SVG_FILE = path.join(__dirname, "./data/generated-image.svg");
const WIDTH = 15;
const HEIGHT = 25;
const PIXEL_SIZE = 20;

interface ImageData {
  width: number;
  height: number;
  pixels: string[];
}

function generateImage(width: number = WIDTH, height: number = HEIGHT): string[] {
  const fieldColor = "#4C342E";
  const zipColor = "#AE5C37";
  const zipColumn = Math.floor(width / 2);
  const zipWidth = 1;

  const pixels: string[] = [];
  const usedSelectors = new Set<string>();

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let color: string;
      let hex: string;
      let attempts = 0;
      const maxAttempts = 100;

      const isZip = x >= zipColumn && x < zipColumn + zipWidth;

      do {
        color = isZip ? varyColor(zipColor, 8) : varyColor(fieldColor, 6);
        const rgb = hexToRgb(color);

        // RGB + column index byte for Solidity selector reconstruction
        const indexByte = x.toString(16).padStart(2, "0");
        hex = rgbToHex(rgb.r, rgb.g, rgb.b) + indexByte;
        attempts++;

        if (attempts >= maxAttempts) {
          const offset = pixels.length % 16;
          const rgb2 = hexToRgb(color);
          rgb2.r = clamp(rgb2.r + offset, 0, 255);
          hex = rgbToHex(rgb2.r, rgb2.g, rgb2.b) + indexByte;
          break;
        }
      } while (usedSelectors.has(hex));

      usedSelectors.add(hex);
      pixels.push(hex);
    }
  }

  return pixels;
}

function generateSVG(pixels: string[], width: number = WIDTH, height: number = HEIGHT): string {
  const svgWidth = width * PIXEL_SIZE;
  const svgHeight = height * PIXEL_SIZE;

  let svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${svgWidth}" height="${svgHeight}" xmlns="http://www.w3.org/2000/svg">
  <rect width="${svgWidth}" height="${svgHeight}" fill="#000000"/>
`;

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const pixelIndex = y * width + x;
      const pixelHex = pixels[pixelIndex];
      const color = "#" + pixelHex.substring(0, 6);

      svg += `  <rect x="${x * PIXEL_SIZE}" y="${
        y * PIXEL_SIZE
      }" width="${PIXEL_SIZE}" height="${PIXEL_SIZE}" fill="${color}"/>\n`;
    }
  }

  svg += `</svg>`;
  return svg;
}

function run() {
  const pixels = generateImage(WIDTH, HEIGHT);
  const dataDir = path.dirname(PIXELS_FILE);

  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }

  const data: ImageData = {
    width: WIDTH,
    height: HEIGHT,
    pixels,
  };

  fs.writeFileSync(PIXELS_FILE, JSON.stringify(data, null, 2));
  console.log(`Saved image pixel data to: ${PIXELS_FILE}`);

  const svg = generateSVG(pixels, WIDTH, HEIGHT);
  fs.writeFileSync(SVG_FILE, svg);
  console.log(`Saved generated SVG image to: ${SVG_FILE}`);
}

try {
  run();
  process.exit(0);
} catch (error) {
  if (error instanceof Error) {
    console.error("Error:", error.message);
    console.error(error.stack);
  }
  process.exit(1);
}
