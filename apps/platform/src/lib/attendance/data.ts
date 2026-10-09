import "server-only";
import { createClient } from "../supabase/server";
import { emptyAttendance, type AttendanceQuery } from "./contracts";
import { projectAttendanceData } from "./input";
export async function loadAttendance(query: AttendanceQuery, resolveOccurrenceRange = false) {
  const rpcQuery = resolveOccurrenceRange && query.event_id && query.occurrence_key ? Object.fromEntries(Object.entries(query).filter(([key]) => key !== "from" && key !== "to")) : query;
  try { const client = await createClient(); const { data, error } = await client.rpc("boss_attendance_read", { p_query: rpcQuery }); return error ? emptyAttendance(query, true) : projectAttendanceData(data, query) ?? emptyAttendance(query, true); }
  catch { return emptyAttendance(query, true); }
}
export async function attendanceNavigationAvailable() { const now = new Date(); const data = await loadAttendance({ view: "family", from: now.toISOString(), to: new Date(now.getTime() + 30 * 86_400_000).toISOString() }); return !data.unavailable && (data.navigation_available || data.features.attendance === true || data.occurrences.length > 0); }
