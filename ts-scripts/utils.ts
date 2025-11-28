import keccak from "keccak";

/* **************************************************************** */
/*                      IMAGE GENERATION UTILS                      */
/* **************************************************************** */

export interface RGB {
  r: number;
  g: number;
  b: number;
}

export function hexToRgb(hex: string): RGB {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16),
      }
    : { r: 0, g: 0, b: 0 };
}

export function rgbToHex(r: number, g: number, b: number): string {
  return ((r << 16) | (g << 8) | b).toString(16).padStart(6, "0");
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function varyColor(baseColor: string, variance: number = 3): string {
  const rgb = hexToRgb(baseColor);
  const r = clamp(rgb.r + Math.floor(Math.random() * variance * 2 - variance), 0, 255);
  const g = clamp(rgb.g + Math.floor(Math.random() * variance * 2 - variance), 0, 255);
  const b = clamp(rgb.b + Math.floor(Math.random() * variance * 2 - variance), 0, 255);
  return "#" + rgbToHex(r, g, b);
}

/* **************************************************************** */
/*                    CONTRACT GENERATION UTILS                     */
/* **************************************************************** */

export function keccak256(data: string): Buffer {
  return keccak("keccak256").update(data).digest();
}

export function getFunctionSelector(signature: string): Buffer {
  const hash = keccak256(signature);
  return hash.subarray(0, 4);
}

export function generateRandomPrefix(attempt: number): string {
  if (attempt === 0) return "f";

  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  const length = Math.floor(attempt / 10) + 1;
  let prefix = "f";

  for (let i = 0; i < length; i++) {
    prefix += chars.charAt(Math.floor(Math.random() * chars.length));
  }

  return prefix;
}
