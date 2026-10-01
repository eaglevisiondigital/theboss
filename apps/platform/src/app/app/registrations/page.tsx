import type { Metadata } from "next";
import { Suspense } from "react";
import { requireSession } from "@/lib/auth/session";
import { loadRegistrations } from "@/lib/registration/data";
import { emptyRegistrationData } from "@/lib/registration/contracts";
import { parseRegistrationQuery } from "@/lib/registration/input";
import { RegistrationConsole } from "@/components/registration/console";

export const metadata: Metadata = { title: "Registrations" };
export const dynamic = "force-dynamic";
export default async function RegistrationsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/registrations");
  const query = parseRegistrationQuery(await searchParams);
  const data = query ? await loadRegistrations(query) : { ...emptyRegistrationData, unavailable: true };
  return <Suspense fallback={<p>Loading your registrations...</p>}><RegistrationConsole data={data} query={query ?? { view: "family" }} /></Suspense>;
}
