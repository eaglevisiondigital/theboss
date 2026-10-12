import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadVolunteers } from "@/lib/volunteers/data";
import { parseVolunteerQuery } from "@/lib/volunteers/input";
import { emptyVolunteers } from "@/lib/volunteers/contracts";
import { VolunteerConsole } from "@/components/volunteers/console";
export const metadata: Metadata = { title: "Volunteers" };
export const dynamic = "force-dynamic";
export default async function VolunteerPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/volunteers"); const params = await searchParams, query = parseVolunteerQuery(params);
  if (!query) return <div className="form-notice" role="status">Review the filters and event selection, then try again.</div>;
  const data = await loadVolunteers(query);
  return <VolunteerConsole key={JSON.stringify(query)} data={data ?? emptyVolunteers} query={query} />;
}
