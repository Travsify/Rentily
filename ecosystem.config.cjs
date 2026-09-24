module.exports = {
  apps: [{
    name: 'rentilly-api',
    script: 'server/index.ts',
    interpreter: 'node_modules/.bin/tsx',
    interpreter_args: '--no-cache',
    instances: 1,
    exec_mode: 'fork',
    wait_ready: false,
    listen_timeout: 15000,
    kill_timeout: 8000,
    restart_delay: 2000,
    max_restarts: 10,
    min_uptime: '5s',
    env: {
      NODE_ENV: 'production',
      PORT: 5000,
      NODE_APP_INSTANCE: '0'
    },
    // Capture logs
    out_file: '/root/.pm2/logs/rentilly-api-out.log',
    error_file: '/root/.pm2/logs/rentilly-api-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true
  }]
};
