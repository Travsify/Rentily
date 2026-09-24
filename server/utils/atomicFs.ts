import fs from 'fs';
import path from 'path';

/**
 * Atomically writes JSON to a file by writing to a unique temp file first,
 * then performing an atomic rename. This prevents truncated / corrupted JSON files
 * if the process is killed or restarts mid-write.
 */
export function writeJsonAtomic(filePath: string, data: any): void {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const tempPath = `${filePath}.${Date.now()}.${Math.random().toString(36).substring(2, 8)}.tmp`;
  try {
    fs.writeFileSync(tempPath, JSON.stringify(data, null, 2), 'utf-8');
    fs.renameSync(tempPath, filePath);
  } catch (err: any) {
    // If temp file remains on error, clean it up
    try {
      if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
    } catch (_) {}
    throw err;
  }
}
