import { footballOperations } from "../football/contracts";
import { parseFootballCommand, projectFootball } from "../football/input";
import { soccerOperations } from "../soccer/contracts";
import { parseSoccerCommand, projectSoccer } from "../soccer/input";
import { basketballOperations } from "../basketball/contracts";
import { parseBasketballCommand, projectBasketball } from "../basketball/input";
import type { Json } from "../supabase/database.types";
import { boundedText, choice, collection, count, dateRange, finiteKeys, integer, isRecord, oneOf, optionalId, optionalTime, queryTimes, text, uuid, validOccurrenceKey, validTimezone } from "../coordination/input";
import { emptyGames, gameFeatureKeys, gameOperations, gameStatuses, type Game, type GameCommand, type GameData, type GameQuery, type GameResult } from "./contracts";

export const sportKeys = ["basketball", "football", "soccer", "volleyball", "baseball", "softball"] as const;
const fields: Record<string, readonly string[]> = {
  "games.configure": ["organization_id", "expected_version", "configuration"],
  "game.create": ["event_id", "expected_event_version", "occurrence_key", "primary_team_id", "sport_key", "competition_type"],
  "game.roster.snapshot": ["game_id", "expected_version"],
  "game.operator.assign": ["game_id", "expected_version", "person_id", "role_assignment_id", "function_key", "team_id", "ends_at"],
  "game.operator.end": ["game_id", "expected_version", "assignment_id"],
  "game.start": ["game_id", "expected_version"],
  "game.transition": ["game_id", "expected_version", "status"],
  "game.score.set": ["game_id", "expected_version", "primary_score", "opponent_score"],
  "game.score.reverse": ["game_id", "expected_version", "operation_id"],
  "game.finalize": ["game_id", "expected_version"],
  "game.reopen": ["game_id", "expected_version", "reason"],
  "game.publish": ["game_id", "expected_version"],
};
export function parseGameCommand(value: unknown): GameCommand | null {
  if (!isRecord(value) || !finiteKeys(value, ["operation", "input"]) || !oneOf(value.operation, gameOperations) || !isRecord(value.input)) return null;
  if (oneOf(value.operation, footballOperations)) return parseFootballCommand(value);
  if (oneOf(value.operation, soccerOperations)) return parseSoccerCommand(value);
  if (oneOf(value.operation, basketballOperations)) return parseBasketballCommand(value);
  const operation = value.operation as GameCommand["operation"], input = value.input;
  if (!finiteKeys(input, fields[operation])) return null;
  for (const [key, item] of Object.entries(input)) {
    if (["game_id", "event_id", "primary_team_id", "person_id", "role_assignment_id", "assignment_id", "operation_id"].includes(key) && !uuid(item)) return null;
    if (key === "team_id" && !uuid(item)) return null;
  }
  if (operation === "games.configure") {
    if (!uuid(input.organization_id) || !integer(input.expected_version, 1) || !isRecord(input.configuration) || !Object.keys(input.configuration).length || !finiteKeys(input.configuration, gameFeatureKeys) || Object.values(input.configuration).some(value => typeof value !== "boolean")) return null;
  } else if (operation === "game.create") {
    if (!uuid(input.event_id) || !integer(input.expected_event_version, 1) || typeof input.occurrence_key !== "string" || !validOccurrenceKey(input.occurrence_key) || !uuid(input.primary_team_id) || !oneOf(input.sport_key, sportKeys) || !oneOf(input.competition_type, ["standard", "tournament"])) return null;
  } else {
    if (!uuid(input.game_id) || !integer(input.expected_version, 1)) return null;
    if (operation === "game.operator.assign" && (!uuid(input.person_id) || !uuid(input.role_assignment_id) || !uuid(input.team_id) || !oneOf(input.function_key, ["game_administrator", "scorekeeper"]) || !optionalTime(input.ends_at))) return null;
    if (operation === "game.operator.end" && !uuid(input.assignment_id)) return null;
    if (operation === "game.transition" && !oneOf(input.status, ["pregame", "live", "paused", "delayed", "suspended", "abandoned"])) return null;
    if (operation === "game.score.set" && (!integer(input.primary_score, 0, 1_000_000) || !integer(input.opponent_score, 0, 1_000_000))) return null;
    if (operation === "game.score.reverse" && !uuid(input.operation_id)) return null;
    if (operation === "game.reopen" && (!boundedText(input.reason, 500) || !input.reason.trim())) return null;
  }
  return { operation, input: input as Record<string, Json | undefined> };
}
export function parseGameQuery(params: Record<string, string | string[] | undefined>, now = new Date()): GameQuery | null {
  const range = queryTimes(params, now); if (!range || !oneOf(params.view ?? "all", ["all", "family"])) return null;
  const query: GameQuery = { view: (params.view ?? "all") as GameQuery["view"], ...range };
  for (const [param, key] of [["org", "organization_id"], ["game", "game_id"], ["team", "team_id"], ["unit", "unit_id"], ["season", "season_id"], ["child", "child_person_id"]] as const) { const value = params[param]; if (value !== undefined && value !== "") { if (!uuid(value)) return null; query[key] = value; } }
  if (params.status !== undefined && params.status !== "") { if (!oneOf(params.status, gameStatuses)) return null; query.status = params.status as GameQuery["status"]; }
  return query;
}
export function gameConsoleKey(query: GameQuery, params: Record<string, string | string[] | undefined>) {
  const { from, to, ...context } = query;
  return JSON.stringify({ ...context, from: params.from === undefined ? null : from, to: params.to === undefined ? null : to });
}
export function projectGameResult(value: unknown): GameResult | null {
  if (!isRecord(value) || !integer(value.version, 1) || typeof value.replayed !== "boolean") return null;
  const common = { version: value.version, replayed: value.replayed, message: text(value, "message", "Saved.", 200) };
  if (uuid(value.game_id)) return { ...common, game_id: value.game_id };
  return value.game_id === null && uuid(value.organization_id) ? { ...common, game_id: null, organization_id: value.organization_id } : null;
}
export function gameResultMatchesCommand(result: GameResult, command: GameCommand) { return command.operation === "games.configure" ? result.game_id === null && result.organization_id === command.input.organization_id : result.game_id !== null && (command.operation === "game.create" || result.game_id === command.input.game_id); }
function projectGame(row: Record<string, unknown>, family: boolean, features: GameData["features"]): Game | null {
  if (!uuid(row.id) || !uuid(row.organization_id) || !uuid(row.event_id) || !integer(row.version, 1) || !oneOf(row.status, gameStatuses) || !optionalTime(row.start_at) || !optionalTime(row.end_at) || typeof row.timezone !== "string" || !validTimezone(row.timezone) || typeof row.occurrence_key !== "string" || !validOccurrenceKey(row.occurrence_key) || !oneOf(row.sport_key, sportKeys) || !isRecord(row.primary) || !isRecord(row.opponent) || !uuid(row.primary.team_id)) return null;
  const raw = isRecord(row.capabilities) && !family ? row.capabilities : {}, capabilities = { manage: raw.manage === true, roster_snapshot: raw.roster_snapshot === true, operate: raw.operate === true, resume: raw.resume === true, start: raw.start === true, finalize: raw.finalize === true, correct: raw.correct === true, publish: raw.publish === true, view_roster: isRecord(row.capabilities) && row.capabilities.view_roster === true };
  const side = (s: Record<string, unknown>) => ({ team_id: optionalId(s.team_id), label: text(s, "label", "Team", 200), score: count(s.score), final_score: integer(s.final_score) ? s.final_score : null });
  const visibleRosterIds = new Set(capabilities.view_roster ? collection(row.roster, r => uuid(r.id) && uuid(r.person_id) && uuid(r.participant_id) && uuid(r.team_id) ? r.id : null, 1000) : []);
  return { id: row.id, organization_id: row.organization_id, event_id: row.event_id, occurrence_key: row.occurrence_key, occurrence_mode: row.occurrence_mode === "recurring" ? "recurring" : "single", title: text(row, "title", "Game", 200), sport_key: row.sport_key, sport_label: text(row, "sport_label", "Sport", 80), primary: side(row.primary), opponent: side(row.opponent), home_away: oneOf(row.home_away, ["home", "away", "neutral"]) ? row.home_away as Game["home_away"] : "neutral", competition_type: row.competition_type === "tournament" ? "tournament" : "standard", start_at: row.start_at as string, end_at: row.end_at as string, timezone: row.timezone as string, venue_label: boundedText(row.venue_label, 200) ? row.venue_label : null, event_status: text(row, "event_status", "scheduled", 40), status: row.status as Game["status"], visibility: text(row, "visibility", "private", 40), publication_state: text(row, "publication_state", "draft", 40), version: row.version, roster_revision: count(row.roster_revision), finalization_count: count(row.finalization_count), reopened: row.reopened === true, engine_locked: row.engine_locked === true || (isRecord(row.basketball) && row.basketball.configured === true) || (isRecord(row.soccer) && row.soccer.configured === true) || (isRecord(row.football) && row.football.configured === true), basketball: row.sport_key === "basketball" ? projectBasketball(row.basketball, { family, visibleRosterIds, live: features.basketball_live_scoring === true && features.basketball_stats === true && features.game_operations === true, stats: features.basketball_live_scoring === true && features.basketball_stats === true, playByPlay: features.basketball_live_scoring === true && features.basketball_play_by_play === true, lineups: features.basketball_lineups === true, canReviewEpochs: capabilities.manage || capabilities.correct }) : null, soccer: row.sport_key === "soccer" ? projectSoccer(row.soccer, { family, visibleRosterIds, live: features.soccer_live_scoring === true && features.soccer_stats === true && features.game_operations === true, stats: features.soccer_live_scoring === true && features.soccer_stats === true, playByPlay: features.soccer_live_scoring === true && features.soccer_play_by_play === true, lineups: features.soccer_lineups === true, canReviewEpochs: capabilities.manage || capabilities.correct }) : null, football: row.sport_key === "football" ? projectFootball(row.football, { family, visibleRosterIds, live: features.football_live_scoring === true && features.football_stats === true && features.game_operations === true, stats: features.football_live_scoring === true && features.football_stats === true, playByPlay: features.football_live_scoring === true && features.football_play_by_play === true, lineups: features.football_lineups === true, canReviewEpochs: capabilities.manage || capabilities.correct }) : null, capabilities,
    roster: capabilities.view_roster ? collection(row.roster, r => uuid(r.id) && uuid(r.person_id) && uuid(r.participant_id) && uuid(r.team_id) ? { id: r.id, person_id: r.person_id, participant_id: r.participant_id, team_id: r.team_id, display_name: text(r, "display_name", "Athlete", 200), jersey_number: boundedText(r.jersey_number, 30) ? r.jersey_number : null, position_label: boundedText(r.position_label, 100) ? r.position_label : null, active: r.active === true, captain: r.captain === true, starter: r.starter === true, availability: text(r, "availability", "unknown", 40), checkin_state: boundedText(r.checkin_state, 40) ? r.checkin_state : null, revision: count(r.revision) } : null, 1000) : [],
    operators: capabilities.manage ? collection(row.operators, r => uuid(r.id) && uuid(r.person_id) && uuid(r.role_assignment_id) && oneOf(r.function_key, ["game_administrator", "scorekeeper"]) ? { id: r.id, person_id: r.person_id, display_name: text(r, "display_name", "Operator", 200), role_assignment_id: r.role_assignment_id, team_id: optionalId(r.team_id), function_key: r.function_key as "game_administrator" | "scorekeeper", status: text(r, "status", "inactive", 30), ends_at: optionalTime(r.ends_at) } : null) : [],
    history: !family && (capabilities.manage || capabilities.operate || capabilities.correct) ? collection(row.history, r => uuid(r.id) && optionalTime(r.created_at) ? { id: r.id, sequence: count(r.sequence), version: count(r.version), operation: text(r, "operation", "Game update", 80), created_at: r.created_at as string, correction_of: optionalId(r.correction_of), summary: text(r, "summary", "Recorded game update", 200) } : null, 200) : [],
    finalizations: !family && (capabilities.manage || capabilities.correct) ? collection(row.finalizations, r => uuid(r.id) && optionalTime(r.created_at) ? { id: r.id, epoch: count(r.epoch), primary_score: count(r.primary_score), opponent_score: count(r.opponent_score), roster_revision: count(r.roster_revision), winner_side: oneOf(r.winner_side, ["primary", "opponent"]) ? r.winner_side as "primary" | "opponent" : null, tied: r.tied === true, created_at: r.created_at as string } : null, 100) : [] };
}
export function projectGameData(value: unknown, query: GameQuery): GameData | null {
  if (!isRecord(value) || !isRecord(value.features) || !Array.isArray(value.games)) return null;
  const base = emptyGames(query), features: GameData["features"] = {};
  for (const key of gameFeatureKeys) if (typeof value.features[key] === "boolean") features[key] = value.features[key];
  const capability = isRecord(value.capabilities) && query.view !== "family" ? value.capabilities : {};
  const capabilities = { configure: capability.configure === true, create: capability.create === true };
  return { ...base, navigation_available: value.navigation_available === true, organization_id: optionalId(value.organization_id), configuration_version: capabilities.configure ? count(value.configuration_version) : 0, features, capabilities, ...(isRecord(value.range) && dateRange(value.range.from, value.range.to) ? { range: { from: value.range.from as string, to: value.range.to as string } } : {}), organizations: collection(value.organizations, choice, 101), teams: collection(value.teams, choice, 200), units: collection(value.units, choice), seasons: collection(value.seasons, choice), sports: collection(value.sports, r => oneOf(r.key, sportKeys) ? { key: r.key as string, label: text(r, "label", "Sport", 80) } : null, 6), games: collection(value.games, r => projectGame(r, query.view === "family", features), 100), more: value.more === true,
    create_candidates: capabilities.create ? collection(value.create_candidates, r => uuid(r.event_id) && integer(r.event_version, 1) && typeof r.occurrence_key === "string" && validOccurrenceKey(r.occurrence_key) && optionalTime(r.start_at) && optionalTime(r.end_at) ? { event_id: r.event_id, event_version: r.event_version, occurrence_key: r.occurrence_key, title: text(r, "title", "Calendar game", 200), start_at: r.start_at as string, end_at: r.end_at as string, home_away: oneOf(r.home_away, ["home", "away", "neutral"]) ? r.home_away as "home" | "away" | "neutral" : "neutral", opponent_label: text(r, "opponent_label", "Opponent", 200), teams: collection(r.teams, choice, 100) } : null) : [],
    operator_candidates: query.view !== "family" && Array.isArray(value.games) && value.games.some(row => isRecord(row) && isRecord(row.capabilities) && row.capabilities.manage === true) ? collection(value.operator_candidates, r => uuid(r.person_id) && uuid(r.role_assignment_id) ? { person_id: r.person_id, role_assignment_id: r.role_assignment_id, display_name: text(r, "display_name", "Operator", 200), team_id: optionalId(r.team_id), functions: Array.isArray(r.functions) ? r.functions.filter((f): f is "game_administrator" | "scorekeeper" => oneOf(f, ["game_administrator", "scorekeeper"])) : [] } : null, 200) : [] };
}
