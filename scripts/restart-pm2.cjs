const { execSync } = require('child_process');

if (process.platform === 'win32') {
  // Skip on local Windows development
  process.exit(0);
}

console.log('[Postbuild] Checking PM2 and reloading server processes...');
const restartCommands = [
  'pm2 restart rentilly-api --update-env',
  'pm2 restart ecosystem.config.cjs --update-env',
  'pm2 restart all --update-env',
  'pm2 reload ecosystem.config.cjs --update-env',
  'npx --yes pm2 restart rentilly-api --update-env',
  'npx --yes pm2 restart all --update-env',
  '/usr/local/bin/pm2 restart all',
  '/usr/bin/pm2 restart all'
];

let restarted = false;
for (const cmd of restartCommands) {
  try {
    const out = execSync(cmd, { shell: '/bin/bash', stdio: 'pipe', timeout: 10000 }).toString();
    console.log(`[Postbuild] ✅ Successfully executed "${cmd}":\n`, out);
    restarted = true;
    break;
  } catch (err) {
    // continue to next candidate
  }
}

if (!restarted) {
  console.warn('[Postbuild] ⚠️ Could not reload PM2 via standard paths. Process will pick up build dist on next cycle.');
}
