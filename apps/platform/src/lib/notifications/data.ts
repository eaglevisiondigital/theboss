import "server-only";
import { createClient } from "../supabase/server";
import { emptyNotifications, type NotificationQuery } from "./contracts";
import { projectNotificationData } from "./input";
export async function loadNotifications(query: NotificationQuery) { try { const client = await createClient(); const { data, error } = await client.rpc("boss_notifications_read", { p_query: query }); return error ? { ...emptyNotifications, unavailable: true } : projectNotificationData(data) ?? { ...emptyNotifications, unavailable: true }; } catch { return { ...emptyNotifications, unavailable: true }; } }
