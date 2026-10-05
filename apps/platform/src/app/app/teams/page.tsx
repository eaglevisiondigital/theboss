import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

import { loadStats } from "@/lib/stat-intelligence/data";
import { StatIntelligenceHub } from "@/components/stat-intelligence/hub";
import { parseStatQuery } from "@/lib/stat-intelligence/input";
import Link from "next/link";

export const metadata: Metadata = { title: "Teams" };

export default async function TeamsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/teams");
  const query = await searchParams;
  const data = await loadAdminView("teams", typeof query.org === "string" ? query.org : undefined);
  const statsQuery = parseStatQuery(query);
  const stats = statsQuery?.team_id && statsQuery.season_id && data.organizationId ? await loadStats("team_season", { sport_key: statsQuery.sport_key, team_id: statsQuery.team_id, season_id: statsQuery.season_id, organization_id: data.organizationId }) : null;
  return <><Link className="button button-outline button-small" href={`/app/statistics${data.organizationId ? `?org=${data.organizationId}` : ""}`}>Season statistics</Link>{stats && <StatIntelligenceHub data={stats} title="Team season" />}<AdminConsole view="teams" data={data} /></>;
}
