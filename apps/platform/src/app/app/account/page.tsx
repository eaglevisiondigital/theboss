import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { AdminConsole } from "@/components/admin/console";

export const metadata: Metadata = { title: "Account" };

export default async function AccountPage() {
  await requireSession("/app/account");

  return <AdminConsole view="account" data={await loadAdminView("account")} />;
}
