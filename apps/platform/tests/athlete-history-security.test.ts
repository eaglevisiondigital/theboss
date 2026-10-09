import assert from "node:assert/strict";
import test from "node:test";
import { parseAthleteHistoryQuery, projectAthleteHistory, projectHistoricalStats } from "../src/lib/athlete-history/input";
import { historyRaw, historyRecord, historyId, historyQuery, childId, adultId, unrelatedChildId, originSeasonId, footballHistoryStats } from "./athlete-history-fixture";
import { zeroStats as basketballStats } from "./basketball-fixture";
import { zeroStats as soccerStats } from "./soccer-fixture";
test("athlete history queries use only subject, sport, season and bounded complete keyset filters", () => {
  assert.deepEqual(parseAthleteHistoryQuery({ org: "unrelated", team: "unrelated", household: "unrelated" }), { limit: 20 });
  assert.deepEqual(parseAthleteHistoryQuery({ child: childId, history_sport: "football", history_season: originSeasonId, history_limit: "50" }), { limit: 50, child_person_id: childId, sport_key: "football", season_id: originSeasonId });
  for (const params of [{ child: [childId, adultId] }, { history_sport: "tennis" }, { history_limit: "51" }, { history_limit: "0" }, { history_limit: ["20"] }, { history_season: "forged" }, { before_sealed_at: historyRecord.sealed_at }]) assert.equal(parseAthleteHistoryQuery(params), null);
  const cursor = { before_sealed_at: historyRecord.sealed_at, before_finalization_id: historyRecord.finalization_id, before_stat_id: historyRecord.id }; assert.ok(parseAthleteHistoryQuery(cursor)); assert.equal(parseAthleteHistoryQuery({ ...cursor, before_stat_id: "invalid" }), null);
});
test("history projection whitelists only selected subject provenance and sport statistics", () => {
  const data = projectAthleteHistory(historyRaw, historyQuery); assert.ok(data); assert.equal(data.records[0].stats.rushing_yards, -2); assert.equal(data.records[0].stats.long_field_goal, null); assert.equal(data.records[0].roster_revision, 2); assert.equal(data.records[0].event_sequence, 0);
  assert.doesNotMatch(JSON.stringify(data), /OMIT_|other_players|private_reason|operator_person_id|full_game_state/);
  for (const record of [{ ...historyRecord, person_id: unrelatedChildId }, { ...historyRecord, participant_id: "forged" }, { ...historyRecord, stats: {} }]) assert.equal(projectAthleteHistory({ ...historyRaw, records: [record] }, historyQuery), null);
  assert.equal(projectAthleteHistory(historyRaw, { ...historyQuery, child_person_id: adultId }), null);
  assert.equal(projectAthleteHistory({ ...historyRaw, subjects: [...historyRaw.subjects, historyRaw.subjects[0]] }, historyQuery), null);
});
test("history filters fail closed when an unrelated sport or season is injected", () => {
  assert.ok(projectAthleteHistory(historyRaw, { ...historyQuery, sport_key: "football", season_id: originSeasonId }));
  assert.equal(projectAthleteHistory(historyRaw, { ...historyQuery, sport_key: "soccer" }), null);
  assert.equal(projectAthleteHistory(historyRaw, { ...historyQuery, season_id: historyId(399) }), null);
  assert.equal(projectAthleteHistory({ ...historyRaw, records: Array(21).fill(historyRecord) }, historyQuery), null);
});
test("history preserves previous epochs and refuses to label reopened or nonlatest seals authoritative", () => {
  for (const extra of [{ latest_sealed: false }, { game_status: "live" }, { game_status: "pregame" }]) { const data = projectAthleteHistory({ ...historyRaw, records: [{ ...historyRecord, ...extra }] }, historyQuery); assert.ok(data); assert.equal(data.records[0].current_authoritative, false); }
  const old = { ...historyRecord, id: historyId(350), finalization_id: historyId(351), epoch: 1, current_authoritative: false, latest_sealed: false }, latest = { ...historyRecord, epoch: 2 }; const data = projectAthleteHistory({ ...historyRaw, records: [latest, old] }, historyQuery); assert.ok(data); assert.deepEqual(data.records.map(row => [row.epoch, row.current_authoritative]), [[2, true], [1, false]]);
});
test("history keyset cursor must belong to last visible authorized record and cannot imply unavailable pages", () => {
  const next_cursor = { sealed_at: historyRecord.sealed_at, finalization_id: historyRecord.finalization_id, stat_id: historyRecord.id };
  assert.ok(projectAthleteHistory({ ...historyRaw, has_more: true, next_cursor }, historyQuery));
  for (const cursor of [{ ...next_cursor, stat_id: historyId(390) }, { ...next_cursor, finalization_id: historyId(391) }, { ...next_cursor, sealed_at: "2026-10-03T23:10:00Z" }, null]) assert.equal(projectAthleteHistory({ ...historyRaw, has_more: true, next_cursor: cursor }, historyQuery), null);
  assert.equal(projectAthleteHistory({ ...historyRaw, next_cursor }, historyQuery), null); assert.equal(projectAthleteHistory({ ...historyRaw, records: [], has_more: true, next_cursor }, historyQuery), null);
});
test("history supports sealed Basketball, Soccer and Football without assuming unavailable Soccer participation", () => {
  const basketball = { ...historyRecord, id: historyId(360), sport_key: "basketball", engine_version: "basketball-v1", stats: basketballStats }, soccer = { ...historyRecord, id: historyId(361), sport_key: "soccer", engine_version: "soccer-v1", stats: soccerStats };
  const data = projectAthleteHistory({ ...historyRaw, records: [historyRecord, basketball, soccer] }, historyQuery); assert.ok(data); assert.deepEqual(data.records.map(row => row.sport_key), ["football", "basketball", "soccer"]); assert.equal(data.records[2].stats.minutes, null); assert.equal(data.records[2].stats.clean_sheet, null);
  assert.equal(projectHistoricalStats("football", { ...footballHistoryStats, passing_attempts: -1 }), null); assert.equal(projectHistoricalStats("soccer", { ...soccerStats, minutes: -1 }), null);
});
