import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Access" };

export default async function AccessPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/access");
  const query = await searchParams;
  const data = await loadAdminView("access", typeof query.org === "string" ? query.org : undefined);
  return <AdminConsole view="access" data={data} />;
}
