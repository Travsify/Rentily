import { Request, Response } from 'express';
import { exec } from 'child_process';

let isDeploying = false;
let lastDeployInfo: any = {
  status: 'idle',
  lastDeployedAt: null,
  commit: null,
  output: null,
};

const DEFAULT_DEPLOY_SECRET = 'rentilly_auto_deploy_secure_key_2026';

function isAuthorized(req: Request): boolean {
  const secretKey = process.env.DEPLOY_SECRET_KEY || DEFAULT_DEPLOY_SECRET;
  const token =
    req.headers['x-deploy-token'] ||
    req.query.token ||
    req.body?.token ||
    (typeof req.headers['authorization'] === 'string' && req.headers['authorization'].startsWith('Bearer ')
      ? req.headers['authorization'].replace('Bearer ', '')
      : null);

  return token === secretKey;
}

export async function handleDeploy(req: Request, res: Response) {
  if (!isAuthorized(req)) {
    return res.status(401).json({
      status: false,
      error: 'Unauthorized: Missing or invalid deployment secret token.',
    });
  }

  if (isDeploying) {
    return res.status(429).json({
      status: false,
      message: 'A deployment is currently in progress. Please wait for it to complete.',
      lastDeployInfo,
    });
  }

  isDeploying = true;
  const startTime = new Date().toISOString();
  console.log(`[AUTO-DEPLOY] 🚀 Deployment initiated at ${startTime}`);

  const repoDir = process.env.REPO_DIR || process.cwd();
  const envPath = 'export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node 2>/dev/null | tail -n 1)/bin';
  const buildCmd = `${envPath} && cd "${repoDir}" && git pull origin main && npm run build`;

  exec(buildCmd, { maxBuffer: 1024 * 1024 * 15, shell: '/bin/bash' }, (error, stdout, stderr) => {
    isDeploying = false;

    if (error) {
      console.error('[AUTO-DEPLOY] ❌ Build failed:', error);
      console.error(stderr);
      lastDeployInfo = {
        status: 'failed',
        failedAt: new Date().toISOString(),
        error: error.message,
        stderr: stderr.slice(-1000),
      };
      return res.status(500).json({
        status: false,
        error: error.message,
        stderr: stderr.slice(-2000),
        stdout: stdout.slice(-2000),
      });
    }

    console.log('[AUTO-DEPLOY] ✅ Git pull & npm build succeeded!');

    lastDeployInfo = {
      status: 'success',
      lastDeployedAt: new Date().toISOString(),
      stdout: stdout.slice(-1000),
    };

    res.json({
      status: true,
      message: 'Code pulled and build completed successfully! Reloading PM2 in 1.5s...',
      deployedAt: lastDeployInfo.lastDeployedAt,
      output: stdout.slice(-1500),
    });

    setTimeout(() => {
      console.log('[AUTO-DEPLOY] 🔄 Reloading PM2 service (rentilly-api)...');
      const reloadCmd = `${envPath} && pm2 reload rentilly-api || pm2 restart rentilly-api`;
      exec(reloadCmd, { shell: '/bin/bash' }, (pm2Err, pm2Out) => {
        if (pm2Err) {
          console.warn('[AUTO-DEPLOY] ⚠️ PM2 reload warning:', pm2Err.message);
        } else {
          console.log('[AUTO-DEPLOY] 🚀 PM2 reload completed:\n', pm2Out);
        }
      });
    }, 1500);
  });
}

export async function getDeployStatus(req: Request, res: Response) {
  if (!isAuthorized(req)) {
    return res.status(401).json({ status: false, error: 'Unauthorized' });
  }

  res.json({
    isDeploying,
    lastDeployInfo,
    serverTime: new Date().toISOString(),
  });
}
