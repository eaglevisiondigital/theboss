import "server-only";
import { createClient } from "../supabase/server";
import { emptyCalendar, type CalendarData, type CalendarQuery } from "./contracts";
import { projectCalendarData } from "./input";
import { parseSelection } from "./temporal";

export async function loadCalendar(query: CalendarQuery): Promise<CalendarData> {
  try {
    const client = await createClient();
    const { data, error } = await client.rpc("boss_calendar_read", { p_query: query });
    return error ? emptyCalendar(query,true) : projectCalendarData(data) ?? emptyCalendar(query,true);
  } catch { return emptyCalendar(query,true); }
}
export async function calendarNavigationAvailable() {
  const data = await loadCalendar(parseSelection({}).query);
  return !data.unavailable && (data.organizations.length > 0 || data.occurrences.length > 0);
}
