import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Organizations" };

export default async function OrganizationsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/organizations");
  const query = await searchParams;
  const search = typeof query.q === "string" ? query.q : undefined;
  const data = await loadAdminView("organizations", typeof query.org === "string" ? query.org : undefined, search);
  return <AdminConsole view="organizations" data={data} query={search} />;
}
