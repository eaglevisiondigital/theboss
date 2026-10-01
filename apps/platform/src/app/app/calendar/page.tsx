import type { Metadata } from "next";
import { Suspense } from "react";
import { requireSession } from "@/lib/auth/session";
import { loadCalendar } from "@/lib/calendar/data";
import { emptyCalendar } from "@/lib/calendar/contracts";
import { parseSelection } from "@/lib/calendar/temporal";
import { CalendarConsole } from "@/components/calendar/console";

export const metadata: Metadata = { title: "Calendar" };
export const dynamic = "force-dynamic";
export default async function CalendarPage({ searchParams }: { searchParams: Promise<Record<string,string | string[] | undefined>> }) {
  await requireSession("/app/calendar");
  const selection = parseSelection(await searchParams);
  const data = selection.invalid ? emptyCalendar(selection.query) : await loadCalendar(selection.query);
  return <Suspense fallback={<p>Loading your schedule...</p>}><CalendarConsole data={data} selection={selection} /></Suspense>;
}
