const MAX_FAILED_ATTEMPTS = 5;
const LOCK_WINDOW_MS = 15 * 60 * 1000;

// In-memory lockout per scope and email. Resets on restart; move to a shared store if the API scales out.
const failures = new Map<string, { count: number; firstAt: number }>();

export function isLocked(key: string): boolean {
  const entry = failures.get(key);
  if (!entry) return false;
  if (Date.now() - entry.firstAt > LOCK_WINDOW_MS) {
    failures.delete(key);
    return false;
  }
  return entry.count >= MAX_FAILED_ATTEMPTS;
}

export function recordFailure(key: string): void {
  const entry = failures.get(key);
  if (!entry || Date.now() - entry.firstAt > LOCK_WINDOW_MS) {
    failures.set(key, { count: 1, firstAt: Date.now() });
  } else {
    entry.count += 1;
  }
}

export function clearFailures(key: string): void {
  failures.delete(key);
}
