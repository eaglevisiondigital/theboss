import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AthleteHistoryHub, athleteHistoryHref } from "../src/components/athlete-history/hub";
import { projectAthleteHistory } from "../src/lib/athlete-history/input";
import { emptyAthleteHistory } from "../src/lib/athlete-history/contracts";
import { historyRaw, historyRecord, historyQuery, childId } from "./athlete-history-fixture";
const render = (raw = historyRaw) => renderToStaticMarkup(createElement(AthleteHistoryHub, { data: projectAthleteHistory(raw, historyQuery)!, query: historyQuery }));
test("Family Hub history is an independent per-game subject view retaining origin and seal provenance", () => {
  const html = render(); for (const text of ["Verified athlete history", "CONTROLLED TEST Child1", "CONTROLLED TEST Former Falcons", "CONTROLLED TEST Fall", "Current authoritative final", "Roster revision 2", "Record provenance", historyRecord.game_id, historyRecord.finalization_id, "Passing", "Rushing"]) assert.ok(html.includes(text), text);
  assert.match(html, /<dd>-2<\/dd>/); assert.doesNotMatch(html, /<h4>Defense<\/h4>|<h4>Kicking and punting<\/h4>/); assert.doesNotMatch(html, /OMIT_|Career totals|Transfer athlete|Export|Share history|Correct a recorded|\/app\/games\?/);
  assert.match(html, /no original-team roster, communication or correction access/);
});
test("history distinguishes preserved epochs and pending-refinalization latest seals", () => {
  assert.match(render({ ...historyRaw, records: [{ ...historyRecord, latest_sealed: false }] }), /Preserved historical epoch/);
  assert.match(render({ ...historyRaw, records: [{ ...historyRecord, game_status: "live" }] }), /Latest seal; game awaiting refinalization/);
});
test("history keyset links preserve subject filters without team, organization or household access context", () => {
  const query = { ...historyQuery, child_person_id: childId, sport_key: "football" as const, before_sealed_at: historyRecord.sealed_at, before_finalization_id: historyRecord.finalization_id, before_stat_id: historyRecord.id };
  const href = athleteHistoryHref(query, true); assert.match(href, /child=/); assert.match(href, /history_sport=football/); assert.match(href, /before_finalization_id=/); assert.doesNotMatch(href, /org=|team=|household=/);
  assert.doesNotMatch(athleteHistoryHref(query), /before_/);
  assert.match(athleteHistoryHref(query, true, historyRecord.organization_id), /org=/);
  assert.doesNotMatch(athleteHistoryHref(query, true, "forged"), /org=/);
});
test("history unavailable and restricted projections fail safely without subject information", () => {
  const renderData = (kind: "unavailable" | "restricted") => renderToStaticMarkup(createElement(AthleteHistoryHub, { data: { ...emptyAthleteHistory(), [kind]: true }, query: historyQuery }));
  assert.match(renderData("restricted"), /restricted for this person/); assert.match(renderData("unavailable"), /temporarily unavailable/); assert.doesNotMatch(renderData("restricted"), /Child1|Former Falcons|Record provenance/);
});
