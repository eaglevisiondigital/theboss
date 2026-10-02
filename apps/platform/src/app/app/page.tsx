import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";
import { loadAttendance } from "@/lib/attendance/data";
import { loadVolunteers } from "@/lib/volunteers/data";
import { parseAttendanceQuery } from "@/lib/attendance/input";
import { parseVolunteerQuery } from "@/lib/volunteers/input";
import { CoordinationHub } from "@/components/coordination/hub";

export const metadata: Metadata = { title: "Home" };

export default async function AppHomePage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession();
  const query = await searchParams;
  const attendanceQuery = parseAttendanceQuery({ org: query.org, view: "family" })!, volunteerQuery = parseVolunteerQuery({ org: query.org, view: "family" })!;
  if (!attendanceQuery || !volunteerQuery) return <p role="status" className="form-notice">Review the organization selection.</p>;
  const [data, attendance, volunteers, staff] = await Promise.all([loadAdminView("home", typeof query.org === "string" ? query.org : undefined), loadAttendance(attendanceQuery), loadVolunteers(volunteerQuery), loadAttendance({ ...attendanceQuery, view: "staff" })]);
  return <><AdminConsole view="home" data={data} /><CoordinationHub attendance={attendance} volunteers={volunteers} staff={staff} attendanceQuery={attendanceQuery} volunteerQuery={volunteerQuery} /></>;
}
