import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";
import { loadAttendance } from "@/lib/attendance/data";
import { loadVolunteers } from "@/lib/volunteers/data";
import { parseAttendanceQuery } from "@/lib/attendance/input";
import { parseVolunteerQuery } from "@/lib/volunteers/input";
import { CoordinationHub } from "@/components/coordination/hub";
import { loadGames } from "@/lib/games/data";
import { parseGameQuery } from "@/lib/games/input";
import { GameHub } from "@/components/games/hub";
import { loadAthleteHistory } from "@/lib/athlete-history/data";
import { parseAthleteHistoryQuery } from "@/lib/athlete-history/input";
import { AthleteHistoryHub } from "@/components/athlete-history/hub";

import { loadStats } from "@/lib/stat-intelligence/data";
import { StatIntelligenceHub } from "@/components/stat-intelligence/hub";
import { parseStatQuery } from "@/lib/stat-intelligence/input";
import Link from "next/link";
import { loadAchievements } from "@/lib/achievements/data";
import { AchievementBadges } from "@/components/achievements/badges";
import type { Json } from "@/lib/supabase/database.types";
import { loadAthleteProfiles } from "@/lib/athlete-profiles/data";

export const metadata: Metadata = { title: "Families" };
export const dynamic = "force-dynamic";

export default async function FamiliesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/families");
  const query = await searchParams;
  const search = typeof query.q === "string" ? query.q : undefined;
  const attendanceQuery = parseAttendanceQuery({ org: query.org, child: query.child, view: "family" }), volunteerQuery = parseVolunteerQuery({ org: query.org, view: "family" });
  const gameQuery = parseGameQuery({ org: query.org, child: query.child, view: "family" });
  const historyQuery = parseAthleteHistoryQuery(query);
  if (!attendanceQuery || !volunteerQuery || !gameQuery || !historyQuery) return <p role="status" className="form-notice">Review the organization, child and history filters.</p>;
  const [data, attendance, volunteers, games, history, profiles] = await Promise.all([loadAdminView("families", typeof query.org === "string" ? query.org : undefined, search), loadAttendance(attendanceQuery), loadVolunteers(volunteerQuery), loadGames(gameQuery), loadAthleteHistory(historyQuery), loadAthleteProfiles()]);
  const familySubject = typeof query.child === "string" ? profiles.subjects.find(p => p.person_id === query.child) : profiles.subjects[0];
  const achievements = familySubject ? await loadAchievements({ profile_id: familySubject.profile_id }) : null;
  const statsQuery = parseStatQuery(query);
  const career = statsQuery ? await loadStats("athlete_career", { sport_key: statsQuery.sport_key, ...(history.subject_person_id ? { person_id: history.subject_person_id } : statsQuery.person_id ? { person_id: statsQuery.person_id } : {}) }) : null;
  return <>{achievements && <section className="admin-section"><h2>Family achievements</h2><p>{familySubject?.display_name}: authorized verified recognition and awards.</p>{achievements.unavailable ? <p role="status">Recognition is temporarily unavailable.</p> : <AchievementBadges allowHistoryLink items={achievements.recognitions as unknown as Record<string, Json>[]} />}</section>}{profiles.subjects.length > 0 && <section className="admin-section"><h2>Athlete profiles and recruiting</h2><p>Review verified history, presentation completeness and private recruiting controls for an authorized athlete.</p><div className="athlete-profile-subjects">{profiles.subjects.map(subject => <Link className="button button-outline button-small" key={subject.profile_id} href={`/app/athletes?profile=${subject.profile_id}`}>{subject.display_name}</Link>)}</div></section>}{career && <><StatIntelligenceHub data={career} title={`Family ${statsQuery!.sport_key} career summary`} /><Link className="button button-outline button-small" href={`/app/statistics?stats_sport=${statsQuery!.sport_key}${history.subject_person_id ? `&child=${history.subject_person_id}` : ""}${data.organizationId ? `&org=${data.organizationId}` : ""}`}>Season and career details</Link></>}<AthleteHistoryHub data={history} query={historyQuery} organizationId={typeof query.org === "string" ? query.org : undefined} /><CoordinationHub family attendance={attendance} volunteers={volunteers} attendanceQuery={attendanceQuery} volunteerQuery={volunteerQuery} /><GameHub family data={games} query={gameQuery} /><AdminConsole view="families" data={data} query={search} /></>;
}
