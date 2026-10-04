export const historySports = ["basketball", "soccer", "football"] as const;
export type HistorySport = typeof historySports[number];
export type HistoryCursor = { sealed_at: string; finalization_id: string; stat_id: string };
export type AthleteHistoryQuery = { child_person_id?: string; sport_key?: HistorySport; season_id?: string; limit: number; before_sealed_at?: string; before_finalization_id?: string; before_stat_id?: string };
export type HistorySubject = { person_id: string; display_name: string; relationship: "self" | "dependent" };
export type HistoricalStats = Record<string, number | boolean | null>;
export type AthleteHistoryRecord = {
  id: string; sport_key: HistorySport; engine_version: string; person_id: string; participant_id: string;
  organization_id: string; organization_name: string; team_id: string; team_name: string;
  origin_team_season_id: string | null; origin_team_season_name: string | null; game_season_id: string | null; game_season_name: string | null;
  game_id: string; event_id: string; occurrence_key: string; roster_id: string; roster_revision: number;
  finalization_id: string; epoch: number; sealed_at: string; event_sequence: number; operation_sequence: number;
  side: "primary" | "opponent"; current_authoritative: boolean; latest_sealed: boolean; game_status: string; stats: HistoricalStats;
};
export type AthleteHistoryData = { subjects: HistorySubject[]; subject_person_id: string | null; records: AthleteHistoryRecord[]; has_more: boolean; next_cursor: HistoryCursor | null; unavailable?: boolean; restricted?: boolean };
export function emptyAthleteHistory(unavailable = false, restricted = false): AthleteHistoryData { return { subjects: [], subject_person_id: null, records: [], has_more: false, next_cursor: null, unavailable, restricted }; }
