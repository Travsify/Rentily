import { readFileSync, writeFileSync } from 'fs';

const file = 'server/services/mapleradBankingService.ts';
let content = readFileSync(file, 'utf-8');

const pattern = /\/\*\*\s*\* Normalizes any incoming Date of Birth to strict DD-MM-YYYY format\s*\*\/\s*static normalizeDob\(raw\?: string\): string \{[\s\S]*?return cleaned;\s*\}/;

const newMethod = `/**
   * Normalizes any incoming Date of Birth to strict DD-MM-YYYY format.
   * Handles: ISO 8601 (1990-05-20T00:00:00.000Z), YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY, DD.MM.YYYY
   */
  static normalizeDob(raw?: string): string {
    if (!raw || !raw.trim()) return '01-01-1990';
    let input = raw.trim();

    // Strip ISO 8601 time component if present (e.g. "1990-05-20T00:00:00.000Z" -> "1990-05-20")
    if (input.includes('T')) {
      input = input.split('T')[0];
    }

    const cleaned = input.replace(/[\\/\\.]/g, '-');
    const parts = cleaned.split('-');
    if (parts.length === 3) {
      if (parts[0].length === 4) {
        // YYYY-MM-DD -> DD-MM-YYYY
        return parts[2].padStart(2, '0') + '-' + parts[1].padStart(2, '0') + '-' + parts[0];
      }
      // DD-MM-YYYY already
      return parts[0].padStart(2, '0') + '-' + parts[1].padStart(2, '0') + '-' + parts[2];
    }

    // Last resort: try Date constructor
    try {
      const d = new Date(raw.trim());
      if (!isNaN(d.getTime())) {
        const day = String(d.getUTCDate()).padStart(2, '0');
        const month = String(d.getUTCMonth() + 1).padStart(2, '0');
        const year = d.getUTCFullYear();
        return day + '-' + month + '-' + year;
      }
    } catch (_) {}

    return cleaned;
  }`;

if (pattern.test(content)) {
  const newContent = content.replace(pattern, newMethod);
  writeFileSync(file, newContent, 'utf-8');
  console.log('SUCCESS: DOB normalizer patched!');
} else {
  console.log('ERROR: Pattern not found in file');
  // Debug: show the actual method area
  const idx = content.indexOf('normalizeDob');
  console.log('Found normalizeDob at index:', idx);
  console.log('Context:', content.slice(idx - 50, idx + 300));
}
