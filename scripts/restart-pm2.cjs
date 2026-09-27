const { execSync } = require('child_process');

if (process.platform === 'win32') {
  // Skip on local Windows development
  process.exit(0);
}

const pm2Home = process.env.PM2_HOME || '/root/.pm2';
const restartCommands = [
  `export PM2_HOME="${pm2Home}" && pm2 reload rentilly-api --update-env`,
  `export PM2_HOME="${pm2Home}" && pm2 restart rentilly-api --update-env`,
  `export PM2_HOME="${pm2Home}" && pm2 reload ecosystem.config.cjs --update-env`,
  `export PM2_HOME="${pm2Home}" && pm2 start ecosystem.config.cjs --update-env`,
  `export PM2_HOME="${pm2Home}" && npx --yes pm2 reload rentilly-api --update-env`,
  `export PM2_HOME="${pm2Home}" && npx --yes pm2 restart rentilly-api --update-env`,
  `export PM2_HOME="${pm2Home}" && /usr/local/bin/pm2 restart all`,
  `export PM2_HOME="${pm2Home}" && /usr/bin/pm2 restart all`,
  'pm2 reload rentilly-api --update-env',
  'pm2 restart rentilly-api --update-env',
  'npx --yes pm2 restart all --update-env'
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
