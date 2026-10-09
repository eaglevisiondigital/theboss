import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAthleteProfiles } from "@/lib/athlete-profiles/data";
import { athleteProfileId } from "@/lib/athlete-profiles/input";
import { AthleteProfileHub } from "@/components/athlete-profiles/hub";
export const metadata: Metadata = { title: "Athlete profiles and recruiting" }; export const dynamic = "force-dynamic";
export default async function AthleteProfilesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) { await requireSession("/app/athletes"); const params = await searchParams, requested = athleteProfileId(Array.isArray(params.profile) ? params.profile[0] : params.profile); let data = await loadAthleteProfiles(requested); if (!requested && data.subjects[0]) data = await loadAthleteProfiles(data.subjects[0].profile_id); return <section className="admin-section athlete-profiles-page"><h1>Athlete profiles and recruiting</h1><p>One longitudinal athlete identity with verified history, explicit provenance and guardian-controlled recruiting visibility.</p>{data.restricted ? <p role="status">This athlete profile is restricted.</p> : data.unavailable ? <p role="alert">Athlete profiles are temporarily unavailable.</p> : <AthleteProfileHub data={data} />}</section>; }
