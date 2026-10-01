import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Families" };

export default async function FamiliesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/families");
  const query = await searchParams;
  const search = typeof query.q === "string" ? query.q : undefined;
  const data = await loadAdminView("families", typeof query.org === "string" ? query.org : undefined, search);
  return <AdminConsole view="families" data={data} query={search} />;
}
