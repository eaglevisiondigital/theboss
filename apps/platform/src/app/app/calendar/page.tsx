import type { Metadata } from "next";
import { Suspense } from "react";
import { requireSession } from "@/lib/auth/session";
import { loadCalendar } from "@/lib/calendar/data";
import { emptyCalendar } from "@/lib/calendar/contracts";
import { parseSelection, validOccurrenceKey } from "@/lib/calendar/temporal";
import { CalendarConsole } from "@/components/calendar/console";
import { uuidPattern } from "@/lib/admin/input";
import { loadVolunteers } from "@/lib/volunteers/data";

export const metadata: Metadata = { title: "Calendar" };
export const dynamic = "force-dynamic";
export default async function CalendarPage({ searchParams }: { searchParams: Promise<Record<string,string | string[] | undefined>> }) {
  await requireSession("/app/calendar");
  const filters = await searchParams;
  const selection = parseSelection(filters);
  const initialEventId = typeof filters.event === "string" && uuidPattern.test(filters.event) ? filters.event : undefined;
  const initialOccurrenceKey = typeof filters.occurrence === "string" && validOccurrenceKey(filters.occurrence) ? filters.occurrence : undefined;
  const [data, volunteers] = await Promise.all([selection.invalid ? emptyCalendar(selection.query) : loadCalendar(selection.query), selection.invalid ? null : loadVolunteers({ view: "upcoming", from: selection.query.from, to: selection.query.to, ...(selection.query.organization_id ? { organization_id: selection.query.organization_id } : {}) })]);
  return <Suspense fallback={<p>Loading your schedule...</p>}><CalendarConsole key={`${initialEventId ?? "calendar"}:${initialOccurrenceKey ?? ""}:${selection.date}:${selection.timezone}`} data={data} selection={selection} initialEventId={initialEventId} initialOccurrenceKey={initialOccurrenceKey} volunteerOrganizationId={volunteers?.features.volunteers === true ? volunteers.organizationId : null} /></Suspense>;
}
