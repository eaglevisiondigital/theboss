import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadNotifications } from "@/lib/notifications/data";
import { emptyNotifications } from "@/lib/notifications/contracts";
import { parseNotificationQuery } from "@/lib/notifications/input";
import { NotificationCenter } from "@/components/communications/notification-center";
export const metadata: Metadata = { title: "Notifications" };
export const dynamic = "force-dynamic";
export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/notifications"); const query = parseNotificationQuery(await searchParams);
  const data = query ? await loadNotifications(query) : { ...emptyNotifications, unavailable: true };
  return <NotificationCenter data={data} query={query ?? { view: "inbox" }} />;
}
