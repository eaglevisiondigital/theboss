import type { TrackingSelection } from "./profile";
import type { TrackingSport } from "./catalog";

// Deliberately no official game, event, person, participant, roster or RPC fields.
export type PracticeParticipant = { key: `practice:${string}`; label: string; side: "primary" | "opponent" };
export type PracticeSession = { mode: "practice"; sport: TrackingSport; profile: TrackingSelection; participants: PracticeParticipant[]; entries: { action: string; participant_key: PracticeParticipant["key"] | null }[] };
export function createPracticeSession(sport: TrackingSport, profile: TrackingSelection): PracticeSession {
  return { mode: "practice", sport, profile: structuredClone(profile), participants: ["primary", "opponent"].flatMap(side => Array.from({ length: 6 }, (_, i) => ({ key: `practice:${side}:${i + 1}` as const, label: `Player ${i + 1}`, side: side as "primary" | "opponent" }))), entries: [] };
}
export function requireOfficialCommand(input: unknown): void {
  if (!input || typeof input !== "object" || "mode" in input || "participant_key" in input || "practice" in input) throw new Error("Practice cannot use official mutation");
}
