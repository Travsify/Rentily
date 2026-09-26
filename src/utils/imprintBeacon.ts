export interface VisitorMetricsSummary {
  totalPageviews: number;
  uniqueVisitors: number;
  todayPageviews: number;
  todayUniqueVisitors: number;
  liveActive: number;
}

export interface VisitorLogEntry {
  id: string;
  visitorId: string;
  page: string;
  referrer: string;
  channel: string;
  device: {
    os: string;
    type: string;
    browser: string;
  };
  country: string;
  ipHash: string;
  timestamp: string;
}

export interface FullTelemetryStats {
  metrics: VisitorMetricsSummary & { lastUpdated: string };
  sources: Record<string, number>;
  devices: Record<string, number>;
  topPages: Record<string, number>;
  recentLogs: VisitorLogEntry[];
}

function getOrCreateVisitorId(): string {
  try {
    let vid = localStorage.getItem('rentilly_visitor_id');
    if (!vid) {
      vid = 'v_' + Math.random().toString(36).substring(2, 10) + Date.now().toString(36);
      localStorage.setItem('rentilly_visitor_id', vid);
    }
    return vid;
  } catch {
    return 'v_' + Math.random().toString(36).substring(2, 10);
  }
}

function getOrCreateSessionId(): string {
  try {
    let sid = sessionStorage.getItem('rentilly_session_id');
    if (!sid) {
      sid = 's_' + Math.random().toString(36).substring(2, 10);
      sessionStorage.setItem('rentilly_session_id', sid);
    }
    return sid;
  } catch {
    return 's_' + Math.random().toString(36).substring(2, 10);
  }
}

let cachedMetrics: VisitorMetricsSummary | null = null;
let lastFiredTime = 0;

export async function fireVisitorImprint(customPage?: string): Promise<VisitorMetricsSummary | null> {
  // Prevent duplicate burst within 5 seconds for the same page view
  const now = Date.now();
  if (now - lastFiredTime < 4000 && cachedMetrics) {
    return cachedMetrics;
  }
  lastFiredTime = now;

  try {
    const visitorId = getOrCreateVisitorId();
    const sessionId = getOrCreateSessionId();
    const page = customPage || window.location.pathname || '/';
    const referrer = document.referrer || '';
    const urlParams = new URLSearchParams(window.location.search);
    const utmSource = urlParams.get('utm_source') || urlParams.get('source') || urlParams.get('ref');

    const payload = {
      visitorId,
      sessionId,
      page,
      referrer,
      utmSource,
    };

    const res = await fetch('/api/telemetry/imprint', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.status && data.metrics) {
        cachedMetrics = data.metrics;
        return data.metrics;
      }
    }
  } catch (err) {
    // Non-blocking telemetry
  }

  return cachedMetrics;
}

export async function fetchFullTelemetryStats(): Promise<FullTelemetryStats | null> {
  try {
    const res = await fetch('/api/telemetry/stats');
    if (res.ok) {
      const data = await res.json();
      if (data.status) {
        return data;
      }
    }
  } catch {}
  return null;
}
