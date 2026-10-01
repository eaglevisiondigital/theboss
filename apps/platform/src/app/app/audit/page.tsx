import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Audit" };

export default async function AuditPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/audit");
  const query = await searchParams;
  const data = await loadAdminView("audit", typeof query.org === "string" ? query.org : undefined);
  return <AdminConsole view="audit" data={data} />;
}
