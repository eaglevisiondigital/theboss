import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Teams" };

export default async function TeamsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/teams");
  const query = await searchParams;
  const data = await loadAdminView("teams", typeof query.org === "string" ? query.org : undefined);
  return <AdminConsole view="teams" data={data} />;
}
