import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAttendance } from "@/lib/attendance/data";
import { parseAttendanceQuery } from "@/lib/attendance/input";
import { emptyAttendance } from "@/lib/attendance/contracts";
import { AttendanceConsole } from "@/components/attendance/console";
export const metadata: Metadata = { title: "Attendance" };
export const dynamic = "force-dynamic";
export default async function AttendancePage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/attendance"); const params = await searchParams, query = parseAttendanceQuery(params);
  if (!query) return <div className="form-notice" role="status">Review the filters and event selection, then try again.</div>;
  const data = await loadAttendance(query, params.from === undefined && params.to === undefined);
  return <AttendanceConsole key={JSON.stringify(query)} data={data ?? emptyAttendance(query)} query={query} />;
}
