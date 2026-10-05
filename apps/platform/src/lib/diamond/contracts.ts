export const diamondSports = ["baseball", "softball"] as const;
export type DiamondSport = typeof diamondSports[number];
export type DiamondSide = "primary" | "opponent";
export const diamondResults = ["single", "double", "triple", "home_run", "walk", "intentional_walk", "hit_by_pitch", "strikeout", "reached_on_error", "fielders_choice", "sacrifice_bunt", "sacrifice_fly", "catcher_interference", "dropped_third_strike", "other_out"] as const;
export type DiamondResult = typeof diamondResults[number];
export const diamondPitches = ["ball", "called_strike", "swinging_strike", "foul", "foul_bunt", "in_play"] as const;
export const diamondCauses = ["hit", "walk", "hit_by_pitch", "error", "fielders_choice", "sacrifice", "stolen_base", "caught_stealing", "pickoff", "wild_pitch", "passed_ball", "balk", "defensive_indifference", "advance_on_play", "interference", "dropped_third_strike", "tiebreak"] as const;
export const diamondOperations = ["diamond.configure", "diamond.lineup.set", "diamond.pa.start", "diamond.pitch.add", "diamond.play.add", "diamond.runner.advance", "diamond.substitute", "diamond.pitcher.change", "diamond.half.start", "diamond.fielding.add", "diamond.event.correct", "diamond.event.reverse"] as const;
export const diamondStatKeys = ["pa", "ab", "runs", "hits", "singles", "doubles", "triples", "home_runs", "rbi", "walks", "hbp", "strikeouts", "stolen_bases", "caught_stealing", "sacrifice_flies", "sacrifice_bunts", "outs_pitched", "batters_faced", "hits_allowed", "runs_allowed", "earned_runs", "walks_allowed", "strikeouts_pitched", "hbp_allowed", "home_runs_allowed", "pitches", "strikes", "wild_pitches", "putouts", "assists", "errors", "double_plays", "avg", "obp", "slg", "ops", "era", "whip", "strike_percentage"] as const;
export type DiamondCoveredStat = { recorded_value: number | null; coverage: "tracked" | "not_tracked" | "partially_tracked" };
export type DiamondView = {
  configured: boolean; sport_key: DiamondSport; engine_version?: "diamond-v1";
  configuration?: DiamondRule; state?: DiamondState;
  capabilities: { configure: boolean; operate: boolean; correct: boolean; stats: boolean; lineups: boolean };
  entry_roster: { id: string; side: DiamondSide; display_name: string; jersey_number: string | null; active: boolean }[];
  players: { roster_id: string; side: DiamondSide; display_name: string; stats: Partial<Record<typeof diamondStatKeys[number], DiamondCoveredStat>> }[];
  teams: { side: DiamondSide; stats: Partial<Record<typeof diamondStatKeys[number], DiamondCoveredStat>> }[];
  plays: { id: string; sequence: number; origin_sequence: number; event_type: string; inning: number; half: "top" | "bottom"; batting_side: DiamondSide; outs: number; runs: number; payload: Record<string, import("../supabase/database.types").Json> }[];
  final_epochs: { epoch: number; current_authoritative: boolean }[];
  tracking: Partial<Record<DiamondSide, { selection: import("../stat-tracking/profile").TrackingSelection; coverage: Record<string, unknown>; profile_version: number; can_manage: boolean }>>;
};
export type DiamondRule = {
  version: "diamond-rules-v1"; sport: DiamondSport; home_side: DiamondSide;
  regulation_innings: number; lineup_size: number; continuous_batting: boolean;
  allow_reentry: boolean; stealing: boolean; dropped_third_strike: "disabled" | "first_unoccupied_or_two_outs";
  foul_bunt_third_strike: boolean; run_cap: number | null; tiebreak_from: number | null;
  dh: "foundation_only" | "none"; dp_flex: "foundation_only" | "none";
  courtesy_runner: "foundation_only" | "none"; mercy_margin: number | null;
  time_limit_minutes: number | null; pitch_limit: number | null; era_innings: number;
};
export type DiamondRunner = {
  key: string; roster_id: string | null; responsible_pitcher: string | null;
  origin: typeof diamondCauses[number]; placed: boolean;
};
export type DiamondMove = {
  from: 0 | 1 | 2 | 3; to: 1 | 2 | 3 | 4 | null; out: boolean;
  cause: typeof diamondCauses[number]; force: boolean; batter_before_first: boolean;
  earned?: boolean; rbi?: boolean;
};
export type DiamondPA = {
  key: string; side: DiamondSide; batter: string | null; pitcher: string | null;
  inning: number; half: "top" | "bottom"; balls: number; strikes: number;
  pitches: number; strike_pitches: number; pitch_coverage: "tracked" | "partially_tracked" | "not_tracked";
  awaiting: "walk" | "strikeout" | "in_play" | null;
};
export type DiamondAppearance = {
  key: string; side: DiamondSide; pitcher: string | null; entry_inning: number;
  entry_half: "top" | "bottom"; inherited: DiamondRunner[]; ended: boolean;
  entry: { inning: number; half: "top" | "bottom"; outs: number; primary_score: number; opponent_score: number };
  exit: { inning: number; half: "top" | "bottom"; outs: number; primary_score: number; opponent_score: number } | null;
  outs_recorded: number; batters_faced: number;
};
export type DiamondState = {
  inning: number; half: "top" | "bottom"; status: "pregame" | "active" | "half_complete";
  outs: number; primary_score: number; opponent_score: number; half_runs: number;
  batting_side: DiamondSide; defensive_side: DiamondSide; bases: (DiamondRunner | null)[];
  orders: Record<DiamondSide, (string | null)[]>; positions: Record<DiamondSide, Record<string, string | null>>;
  used: Record<DiamondSide, string[]>; cursors: Record<DiamondSide, number>;
  pitchers: Record<DiamondSide, string | null>; lineup_revision: number;
  pa: DiamondPA | null; appearances: DiamondAppearance[];
  completed_halves: { inning: number; half: "top" | "bottom"; side: DiamondSide; runs: number; outs: number; reason: "third_out" | "run_cap" }[];
};
export type DiamondFact =
  | { kind: "lineup_set"; side: DiamondSide; order: (string | null)[]; positions: Record<string, string | null>; pitcher: string | null }
  | { kind: "half_start"; placed_runner?: { roster_id: string | null; key: string } }
  | { kind: "pa_start"; key: string; batter: string | null; pitch_tracking: boolean }
  | { kind: "pitch"; pitch_gap?: boolean; outcome: typeof diamondPitches[number]; pitch_tracking: boolean }
  | { kind: "play"; pitch_gap?: boolean; result: DiamondResult; moves: DiamondMove[] }
  | { kind: "advance"; moves: DiamondMove[] }
  | { kind: "pitcher_change"; side: DiamondSide; pitcher: string | null; key: string }
  | { kind: "fielding"; side: DiamondSide; roster_id: string | null; position: string | null; stat: "putouts" | "assists" | "errors" | "double_plays"; play_event_id: string }
  | { kind: "substitution"; side: DiamondSide; out_roster_id: string; in_roster_id: string; mode: "offensive" | "defensive" | "pinch_hitter" | "pinch_runner"; position?: string };
