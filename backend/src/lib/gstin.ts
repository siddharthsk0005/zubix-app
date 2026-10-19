const CHARSET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const GSTIN_FORMAT = /^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;

/** Computes the GSTIN check character (mod 36, weights 1 and 2). */
function checkCharacter(body: string): string {
  let sum = 0;
  for (let i = 0; i < body.length; i += 1) {
    const factor = i % 2 === 0 ? 1 : 2;
    const product = CHARSET.indexOf(body[i]) * factor;
    sum += Math.floor(product / 36) + (product % 36);
  }
  return CHARSET[(36 - (sum % 36)) % 36];
}

/** Offline GST check: 15-character format plus the checksum. No government lookup. */
export function isValidGstin(value: string): boolean {
  if (value.length !== 15 || !GSTIN_FORMAT.test(value)) return false;
  return checkCharacter(value.slice(0, 14)) === value[14];
}
