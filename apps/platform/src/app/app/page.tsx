import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Home" };

export default async function AppHomePage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession();
  const query = await searchParams;
  const data = await loadAdminView("home", typeof query.org === "string" ? query.org : undefined);
  return <AdminConsole view="home" data={data} />;
}
