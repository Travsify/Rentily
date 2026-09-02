/**
 * Standardizes user/partner/landlord ops IDs to RNT-XXX (max 3 alphanumeric characters).
 * Example: RNT-7A9, RNT-B01, RNT-K22
 */
export function formatOpsId(userId?: string, isPartner: boolean = false): string {
  if (!userId) {
    return isPartner ? 'RNT-P01' : 'RNT-L01';
  }
  const clean = userId.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  if (clean.length >= 3) {
    return `RNT-${clean.slice(0, 3)}`;
  }
  return `RNT-${clean.padEnd(3, 'X')}`;
}
