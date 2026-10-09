import Link from "next/link";
import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAchievements } from "@/lib/achievements/data";
import { statUuid } from "@/lib/stat-intelligence/input";
import { AchievementHub } from "@/components/achievements/hub";
export const metadata: Metadata = { title: "Awards and achievements" }; export const dynamic = "force-dynamic";
export default async function AchievementsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/achievements"); const params = await searchParams, query: Record<string, string> = {};
  for (const [key, field] of Object.entries({ org: "organization_id", team: "team_id", profile: "profile_id", recognition: "recognition_id", after: "after_id" })) if (params[key] !== undefined) { if (!statUuid(params[key])) return <p role="status">Review the recognition filters.</p>; query[field] = params[key] as string; }
  if (!query.organization_id && !query.profile_id && !query.recognition_id) return <section className="admin-section"><h1>Awards and achievements</h1><p>Choose an organization from Home or an authorized athlete profile to review verified recognition.</p><Link className="button button-outline button-small" href="/app">Choose organization</Link><Link className="button button-outline button-small" href="/app/athletes">Choose athlete</Link></section>;
  const data = await loadAchievements(query);
  return <section className="admin-section achievements-page"><h1>Awards and achievements</h1><p>Verified accomplishments, organization-selected honors and their source history. Earning a recognition does not publish it.</p>{data.restricted ? <p role="status">This recognition scope is restricted.</p> : data.unavailable ? <p role="alert">Achievements are temporarily unavailable.</p> : <AchievementHub data={data} organizationId={query.organization_id} />}</section>;
}
