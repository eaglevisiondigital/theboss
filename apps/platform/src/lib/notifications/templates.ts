export const notificationCategories = ["events", "registration", "fees", "communications", "security", "attendance", "volunteers"] as const;
export type NotificationCategory = typeof notificationCategories[number];
export type EmailTemplate = Readonly<{ subject: string; preheader: string; html: string; text: string }>;
export type EmailTemplateInput = Readonly<{ title: string; summary: string; destination: string; organizationName?: string }>;
const uuid = "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
const sourceUuid = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
// Database-generated references are opaque UUIDs; no external URL or arbitrary
// query parameter becomes an email CTA. The destination still authorizes on GET.
export function safeNotificationDestination(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 512) return false;
  const timezone = "(?:[A-Za-z0-9_-]|%2F|%2B){1,300}";
  const occurrence = "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}%3A[0-9]{2}%3A[0-9]{2}";
  const patterns = [
    new RegExp(`^/app/calendar\\?org=${sourceUuid}&event=${sourceUuid}(?:&date=[0-9]{4}-[0-9]{2}-[0-9]{2}(?:&tz=${timezone}(?:&occurrence=${occurrence})?)?)?$`, "i"),
    new RegExp(`^/app/registrations\\?org=${sourceUuid}&registration=${sourceUuid}$`, "i"),
    new RegExp(`^/app/registrations\\?view=family&org=${sourceUuid}$`, "i"),
    new RegExp(`^/app/messages\\?org=${sourceUuid}&thread=${sourceUuid}$`, "i"),
    new RegExp(`^/app/attendance\\?org=${sourceUuid}&event=${sourceUuid}&occurrence=${occurrence}$`, "i"),
    new RegExp(`^/app/volunteers\\?org=${sourceUuid}&shift=${sourceUuid}$`, "i"),
    new RegExp(`^/app/volunteers\\?org=${sourceUuid}&event=${sourceUuid}$`, "i"),
  ];
  if (!patterns.some(pattern => pattern.test(value))) return false;
  const query = new URL(value, "https://thebossplatform.netlify.app").searchParams;
  const date = query.get("date");
  const validDay = (day: string) => !Number.isNaN(Date.parse(`${day}T00:00:00Z`)) && new Date(`${day}T00:00:00Z`).toISOString().slice(0, 10) === day;
  if (date && !validDay(date)) return false;
  const zone = query.get("tz");
  if (zone) {
    if (zone.length > 100 || !/^[A-Za-z0-9_+-]+(?:\/[A-Za-z0-9_+-]+)*$/.test(zone)) return false;
    try { new Intl.DateTimeFormat("en", { timeZone: zone }); } catch { return false; }
  }
  const key = query.get("occurrence");
  if (key && (!validDay(key.slice(0, 10)) || Number(key.slice(11, 13)) > 23 || Number(key.slice(14, 16)) > 59 || Number(key.slice(17, 19)) > 59)) return false;
  return true;
}
export function stableDeliveryKey(deliveryId: string): string {
  if (!new RegExp(`^${uuid}$`, "i").test(deliveryId)) throw new Error("Invalid delivery identifier.");
  return `boss-notification:${deliveryId.toLowerCase()}`;
}
function escapeHtml(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}
function textField(value: string, maximum: number): string {
  const hasControlCharacter = [...value].some(character => {
    const code = character.charCodeAt(0);
    return code === 127 || (code < 32 && code !== 9 && code !== 10 && code !== 13);
  });
  if (!value.trim() || value.length > maximum || hasControlCharacter) throw new Error("Invalid notification template.");
  return value.trim();
}
export function renderNotificationEmail(input: EmailTemplateInput, platformOrigin: string): EmailTemplate {
  const origin = new URL(platformOrigin);
  if (origin.protocol !== "https:" || origin.pathname !== "/" || origin.search || origin.hash || origin.username || origin.password || !safeNotificationDestination(input.destination)) throw new Error("Invalid notification destination.");
  const title = textField(input.title, 120);
  if (/[\r\n]/.test(title)) throw new Error("Invalid notification subject.");
  const summary = textField(input.summary, 400);
  const organization = input.organizationName ? textField(input.organizationName, 120) : "Boss";
  const destination = `${origin.origin}${input.destination}`;
  const html = `<html><body style="margin:0;background:#f5f5f5;font-family:Arial,sans-serif;color:#171717"><div style="max-width:600px;margin:24px auto;background:#fff;padding:28px"><div style="color:#f97316;font-size:24px;font-weight:bold">BOSS</div><p>${escapeHtml(organization)}</p><h1 style="font-size:24px">${escapeHtml(title)}</h1><p>${escapeHtml(summary)}</p><p><a style="background:#f97316;color:#111;padding:12px 18px;text-decoration:none;display:inline-block" href="${escapeHtml(destination)}">Open Boss</a></p><p style="font-size:12px;color:#555">Sign in to review the current record and your notification preferences.</p></div></body></html>`;
  return Object.freeze({ subject: title, preheader: summary, html, text: `${organization}\n\n${title}\n\n${summary}\n\nOpen Boss: ${destination}\n\nSign in to review the current record and your notification preferences.` });
}
