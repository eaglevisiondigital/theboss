import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { loadAthleteHistory } from "@/lib/athlete-history/data";
import { loadStats } from "@/lib/stat-intelligence/data";
import { parseStatQuery, statUuid } from "@/lib/stat-intelligence/input";
import { statSports } from "@/lib/stat-intelligence/contracts";
import { canRebuildStatScope } from "@/lib/stat-intelligence/management";
import { StatManagement } from "@/components/stat-intelligence/management";
import { StatIntelligenceHub } from "@/components/stat-intelligence/hub";
export const metadata: Metadata = { title: "Season and career statistics" };
export const dynamic = "force-dynamic";
export default async function StatisticsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/statistics");
  const raw = await searchParams, query = parseStatQuery(raw);
  if (!query) return <p role="status">Review the statistical filters.</p>;
  const [admin, history] = await Promise.all([loadAdminView("teams", query.organization_id), loadAthleteHistory({ child_person_id: query.person_id, sport_key: query.sport_key, limit: 50 })]);
  const personQuery = { sport_key: query.sport_key, ...(history.subject_person_id ? { person_id: history.subject_person_id } : query.person_id ? { person_id: query.person_id } : {}) };
  const career = await loadStats("athlete_career", personQuery);
  const season = query.season_id ? await loadStats("athlete_season", { ...personQuery, season_id: query.season_id, ...(query.organization_id && query.team_id ? { organization_id: query.organization_id, team_id: query.team_id } : {}) }) : null;
  const team = query.season_id && query.team_id && query.organization_id ? await loadStats("team_season", { sport_key: query.sport_key, season_id: query.season_id, team_id: query.team_id, organization_id: query.organization_id }) : null;
  const teamLabels = Object.fromEntries((admin.records.teams ?? []).map(r => [r.id, r.label])), seasonLabels = Object.fromEntries((admin.records.seasons ?? []).map(r => [r.id, r.label]));
  const historySeasons = new Map(history.records.filter(r => statUuid(r.game_season_id)).map(r => [r.game_season_id!, r.game_season_name ?? "Recorded season"]));
  for (const s of career.segments) if (s.season_id) historySeasons.set(s.season_id, seasonLabels[s.season_id] ?? "Recorded season");
  for (const r of admin.records.seasons ?? []) historySeasons.set(r.id, r.label);
  return <><section className="admin-section"><h1>Season and career statistics</h1><form action="/app/statistics" method="get" className="athlete-history-filters">{query.organization_id && <input type="hidden" name="org" value={query.organization_id} />}<label className="form-field"><span>Athlete</span><select name="child" defaultValue={history.subject_person_id ?? ""}>{history.subjects.map(s => <option key={s.person_id} value={s.person_id}>{s.display_name}</option>)}</select></label><label className="form-field"><span>Sport</span><select name="stats_sport" defaultValue={query.sport_key}>{statSports.map(s => <option key={s} value={s}>{s[0].toUpperCase() + s.slice(1)}</option>)}</select></label><label className="form-field"><span>Season</span><select name="stats_season" defaultValue={query.season_id ?? ""}><option value="">Career only</option>{Array.from(historySeasons).map(([id, name]) => <option key={id} value={id}>{name}</option>)}</select></label><label className="form-field"><span>Originating team</span><select name="stats_team" defaultValue={query.team_id ?? ""}><option value="">All authorized origins</option>{(admin.records.teams ?? []).map(r => <option key={r.id} value={r.id}>{r.label}</option>)}</select></label><button type="submit" className="button button-outline button-small">View statistics</button></form></section>{season && <StatIntelligenceHub data={season} title="Athlete season" teamLabels={teamLabels} seasonLabels={seasonLabels} />}<StatIntelligenceHub data={career} title="Athlete career" teamLabels={teamLabels} seasonLabels={seasonLabels} />{team && <><StatIntelligenceHub data={team} title="Team season" teamLabels={teamLabels} seasonLabels={seasonLabels} />{canRebuildStatScope(admin, query.organization_id) && query.organization_id && query.team_id && query.season_id && <section className="admin-section"><StatManagement key={`${query.organization_id}:${query.team_id}:${query.season_id}:${query.sport_key}`} query={{ organization_id: query.organization_id, team_id: query.team_id, season_id: query.season_id, sport_key: query.sport_key }} /></section>}</>}</>;
}
