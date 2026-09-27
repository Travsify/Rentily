/**
 * Utility to detect and block disposable, temporary, and burner email addresses.
 * Prevents automated bot registrations and promotional bonus abuse.
 */

const DISPOSABLE_DOMAINS = new Set([
  'yopmail.com',
  'yopmail.fr',
  'yopmail.net',
  'tempmail.com',
  'temp-mail.org',
  'temp-mail.io',
  '10minutemail.com',
  '10minutemail.net',
  'guerrillamail.com',
  'guerrillamail.net',
  'guerrillamail.org',
  'mailinator.com',
  'throwawaymail.com',
  'sharklasers.com',
  'dispostable.com',
  'dropmail.me',
  'pickmail.org',
  '10mail.org',
  'ozsaip.com',
  'shopdevo.com',
  'emltmp.com',
  'voewo.com',
  'duck.com',
  'ncleap.com',
  '282mail.com',
  'olipii.com',
  'gmeenramy.com',
  'otona.uk',
  'spamok.com',
  'vendprop.com',
  'pretoct.com',
  'kywa.uk',
  'sendapp.uk',
  'inboxbear.com',
  'mohmal.com',
  'generator.email',
  'trashmail.com',
  'getnada.com',
  'crazymailing.com',
  'nada.ltd',
  'burnermail.io',
  'fakemailgenerator.com',
  'fakemail.net',
  'emailondeck.com',
  'mytemp.email',
  'mintemail.com',
  'maildrop.cc',
  'harakirimail.com',
  'jetable.org',
  'tempail.com',
  'disposablemail.com',
  'inboxkitten.com',
  'mailcatch.com',
  'mailsac.com',
  'trashmail.net',
  'trashmail.me',
  'spambog.com',
  'tempmailaddress.com',
  'minuteinbox.com',
  'tmail.io'
]);

export function isDisposableEmail(email: string): boolean {
  if (!email || typeof email !== 'string') return false;
  const clean = email.toLowerCase().trim();
  const atIdx = clean.lastIndexOf('@');
  if (atIdx === -1) return true;

  const domain = clean.slice(atIdx + 1).trim();
  if (DISPOSABLE_DOMAINS.has(domain)) return true;

  for (const blocked of DISPOSABLE_DOMAINS) {
    if (domain.endsWith('.' + blocked)) {
      return true;
    }
  }

  if (
    domain.includes('tempmail') ||
    domain.includes('dispos') ||
    domain.includes('burner') ||
    domain.includes('throwaway') ||
    domain.includes('fake') ||
    domain.includes('spambox') ||
    domain.includes('trash')
  ) {
    return true;
  }

  return false;
}
