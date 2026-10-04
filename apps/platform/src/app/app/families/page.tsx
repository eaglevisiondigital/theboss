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

export const metadata: Metadata = { title: "Families" };

export default async function FamiliesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/families");
  const query = await searchParams;
  const search = typeof query.q === "string" ? query.q : undefined;
  const attendanceQuery = parseAttendanceQuery({ org: query.org, child: query.child, view: "family" }), volunteerQuery = parseVolunteerQuery({ org: query.org, view: "family" });
  const gameQuery = parseGameQuery({ org: query.org, child: query.child, view: "family" });
  if (!attendanceQuery || !volunteerQuery || !gameQuery) return <p role="status" className="form-notice">Review the organization and child filters.</p>;
  const [data, attendance, volunteers, games] = await Promise.all([loadAdminView("families", typeof query.org === "string" ? query.org : undefined, search), loadAttendance(attendanceQuery), loadVolunteers(volunteerQuery), loadGames(gameQuery)]);
  return <><CoordinationHub family attendance={attendance} volunteers={volunteers} attendanceQuery={attendanceQuery} volunteerQuery={volunteerQuery} /><GameHub family data={games} query={gameQuery} /><AdminConsole view="families" data={data} query={search} /></>;
}
