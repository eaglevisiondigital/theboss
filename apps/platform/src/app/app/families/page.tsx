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
  const [data, attendance, volunteers, games, history] = await Promise.all([loadAdminView("families", typeof query.org === "string" ? query.org : undefined, search), loadAttendance(attendanceQuery), loadVolunteers(volunteerQuery), loadGames(gameQuery), loadAthleteHistory(historyQuery)]);
  return <><AthleteHistoryHub data={history} query={historyQuery} organizationId={typeof query.org === "string" ? query.org : undefined} /><CoordinationHub family attendance={attendance} volunteers={volunteers} attendanceQuery={attendanceQuery} volunteerQuery={volunteerQuery} /><GameHub family data={games} query={gameQuery} /><AdminConsole view="families" data={data} query={search} /></>;
}
