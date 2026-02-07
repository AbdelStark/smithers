export function formatTime(ms: number): string {
  return new Date(ms).toLocaleTimeString();
}

export function formatDuration(startMs: number, endMs: number | null): string {
  const end = endMs ?? Date.now();
  const delta = Math.max(0, end - startMs);
  const seconds = Math.floor(delta / 1000);
  const mins = Math.floor(seconds / 60);
  const hours = Math.floor(mins / 60);
  const parts: string[] = [];
  if (hours) parts.push(`${hours}h`);
  if (mins % 60 || !hours) parts.push(`${mins % 60}m`);
  if (!hours && mins < 5) parts.push(`${seconds % 60}s`);
  return parts.join(" ");
}

export function shortenPath(path: string, max = 28): string {
  if (path.length <= max) return path;
  return `…${path.slice(-max)}`;
}

export function truncate(value: string, max = 120): string {
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1)}…`;
}

export function stateColor(state: string): { bg: string; stroke: string } {
  switch (state) {
    case "in-progress":
      return { bg: "#0D1530", stroke: "#4C7DFF" };
    case "finished":
      return { bg: "#0A1F1A", stroke: "#3DDC97" };
    case "failed":
      return { bg: "#1E0A12", stroke: "#FF3B5C" };
    case "waiting-approval":
      return { bg: "#1A1508", stroke: "#F2A43A" };
    case "cancelled":
    case "skipped":
      return { bg: "#10141A", stroke: "#5A6577" };
    default:
      return { bg: "#10141A", stroke: "#2C3A4E" };
  }
}
