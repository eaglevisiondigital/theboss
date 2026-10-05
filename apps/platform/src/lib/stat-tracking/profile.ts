import { catalogVersion, statCatalog, type TrackingSport } from "./catalog";

export const trackingPresets = ["score_only", "essential", "standard", "advanced", "full", "custom"] as const;
export type TrackingPreset = typeof trackingPresets[number];
export type TrackingSelection = { catalog_version: string; preset: TrackingPreset; enabled: string[]; quick: string[] };
const essentials: Record<TrackingSport, string[]> = {
  basketball: ["player_attribution", "assists", "offensive_rebounds", "defensive_rebounds"],
  soccer: ["player_attribution", "assists", "shots", "saves"],
  football: ["player_attribution", "quick_rush", "quick_pass_complete", "quick_pass_incomplete"],
  volleyball: ["player_attribution", "kills", "assists", "digs", "service_aces", "service_errors", "solo_blocks", "block_assists"],
};
export function resolveSelection(sport: TrackingSport, preset: TrackingPreset, selected: readonly string[] = [], quick?: readonly string[]): TrackingSelection {
  const catalog = statCatalog[sport];
  if (!trackingPresets.includes(preset)) throw new Error("Unknown tracking preset");
  if (preset !== "custom" && selected.length) throw new Error("Preset cannot contain custom selections");
  const seed = preset === "custom" ? selected : preset === "score_only" ? [] : preset === "essential" ? essentials[sport] : catalog.filter(e => e.available && e.classification === "optional").map(e => e.key);
  if (new Set(seed).size !== seed.length) throw new Error("Duplicate enabled stat");
  const enabled = new Set(catalog.filter(e => e.classification === "required").map(e => e.key));
  const add = (key: string) => {
    const stat = catalog.find(e => e.key === key);
    if (!stat?.available) throw new Error("Unsupported stat");
    if (enabled.has(key)) return;
    enabled.add(key); stat.dependencies.forEach(add);
  };
  seed.forEach(add);
  // Derived measures become available only if every dependency is tracked.
  for (let i = 0; i < catalog.length; i++) for (const e of catalog) if (e.available && e.classification === "derived" && e.dependencies.length && e.dependencies.every(k => enabled.has(k))) enabled.add(e.key);
  const defaultQuick = seed.filter(k => catalog.find(e => e.key === k)?.quick_eligible).slice(0, 8);
  const ordered = [...(quick ?? defaultQuick)];
  if (ordered.length > 8 || new Set(ordered).size !== ordered.length || ordered.some(k => !enabled.has(k) || !catalog.find(e => e.key === k)?.quick_eligible)) throw new Error("Invalid Quick Stats");
  return { catalog_version: catalogVersion, preset, enabled: catalog.filter(e => enabled.has(e.key)).map(e => e.key), quick: ordered };
}
export type Coverage = "tracked" | "not_tracked" | "partially_tracked";
export type CoverageInterval = { from_sequence: number; enabled: boolean; snapshot_id: string };
export type CoveredValue = { recorded_value: number | null; coverage: Coverage; reason: "declared" | "legacy_unknown" };
export function coveredValue(value: number | null, intervals: readonly CoverageInterval[] | null, startSequence: number, cutoff: number): CoveredValue {
  if (intervals === null || !intervals.length) return { recorded_value: value, coverage: "partially_tracked", reason: "legacy_unknown" };
  if (!Number.isSafeInteger(startSequence) || !Number.isSafeInteger(cutoff) || cutoff < startSequence || intervals.some((v, i) => !Number.isSafeInteger(v.from_sequence) || v.from_sequence < 0 || i > 0 && v.from_sequence <= intervals[i - 1].from_sequence)) throw new Error("Invalid coverage interval");
  const relevant = intervals.filter(v => v.from_sequence <= cutoff);
  const atStart = relevant.filter(v => v.from_sequence <= startSequence).at(-1);
  const during = relevant.filter(v => v.from_sequence > startSequence);
  const states = [...(atStart ? [atStart.enabled] : []), ...during.map(v => v.enabled)];
  const coverage: Coverage = !atStart ? "partially_tracked" : states.every(Boolean) ? "tracked" : states.every(v => !v) ? "not_tracked" : "partially_tracked";
  return { recorded_value: coverage === "not_tracked" ? null : value, coverage, reason: "declared" };
}
export function contextualPrompts(sport: TrackingSport, action: string, profile: TrackingSelection): string[] {
  return [...new Set(statCatalog[sport].filter(e => e.actions.includes(action)).flatMap(e => e.prompts))].filter(k => profile.enabled.includes(k));
}
