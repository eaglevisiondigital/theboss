import { emptyNotifications, type NotificationData, type NotificationQuery } from "./contracts";
import { projectNotificationData } from "./input";
import { isRecord } from "../communications/input";

type NotificationReader = (request: { p_query: NotificationQuery }) => PromiseLike<{ data: unknown; error: unknown }>;

export async function readNotifications(query: NotificationQuery, read: NotificationReader): Promise<NotificationData> {
  const unavailable = () => ({ ...emptyNotifications, unavailable: true });
  try {
    const { data, error } = await read({ p_query: query });
    if (error) return isRecord(error) && error.code === "PT403" ? { ...emptyNotifications, accessDenied: true } : unavailable();
    return projectNotificationData(data) ?? unavailable();
  } catch { return unavailable(); }
}
