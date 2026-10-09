import type { Metadata } from "next";
import { Suspense } from "react";
import { requireSession } from "@/lib/auth/session";
import { loadCalendar } from "@/lib/calendar/data";
import { emptyCalendar } from "@/lib/calendar/contracts";
import { parseSelection, validOccurrenceKey } from "@/lib/calendar/temporal";
import { CalendarConsole } from "@/components/calendar/console";
import { uuidPattern } from "@/lib/admin/input";
import { loadVolunteers } from "@/lib/volunteers/data";
import { loadGames } from "@/lib/games/data";

export const metadata: Metadata = { title: "Calendar" };
export const dynamic = "force-dynamic";
export default async function CalendarPage({ searchParams }: { searchParams: Promise<Record<string,string | string[] | undefined>> }) {
  await requireSession("/app/calendar");
  const filters = await searchParams;
  const selection = parseSelection(filters);
  const initialEventId = typeof filters.event === "string" && uuidPattern.test(filters.event) ? filters.event : undefined;
  const initialOccurrenceKey = typeof filters.occurrence === "string" && validOccurrenceKey(filters.occurrence) ? filters.occurrence : undefined;
  const [data, volunteers] = await Promise.all([selection.invalid ? emptyCalendar(selection.query) : loadCalendar(selection.query), selection.invalid ? null : loadVolunteers({ view: "upcoming", from: selection.query.from, to: selection.query.to, ...(selection.query.organization_id ? { organization_id: selection.query.organization_id } : {}) })]);
  const games = !selection.invalid && data.occurrences.some(occurrence => occurrence.game) ? await loadGames({ view: selection.query.view === "personal" ? "family" : "all", from: selection.query.from, to: selection.query.to, organization_id: selection.query.organization_id, team_id: selection.query.team_id, unit_id: selection.query.unit_id, season_id: selection.query.season_id, child_person_id: selection.query.child_id }) : null;
  const gameLinks = games?.games.map(({ id, organization_id, event_id, occurrence_key, occurrence_mode, status, primary, opponent }) => ({ id, organization_id, event_id, occurrence_key, occurrence_mode, status, primary: { label: primary.label, score: primary.score, final_score: primary.final_score }, opponent: { label: opponent.label, score: opponent.score, final_score: opponent.final_score } })) ?? [];
  return <Suspense fallback={<p>Loading your schedule...</p>}><CalendarConsole key={`${initialEventId ?? "calendar"}:${initialOccurrenceKey ?? ""}:${selection.date}:${selection.timezone}`} data={data} selection={selection} initialEventId={initialEventId} initialOccurrenceKey={initialOccurrenceKey} volunteerOrganizationId={volunteers?.features.volunteers === true ? volunteers.organizationId : null} gameLinks={gameLinks} /></Suspense>;
}
