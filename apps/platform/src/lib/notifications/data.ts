import "server-only";
import { createClient } from "../supabase/server";
import type { NotificationQuery } from "./contracts";
import { readNotifications } from "./read";

export async function loadNotifications(query: NotificationQuery) {
  return readNotifications(query, async request => {
    const client = await createClient();
    return client.rpc("boss_notifications_read", request);
  });
}
