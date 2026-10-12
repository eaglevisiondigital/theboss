import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { CommunicationsConsole } from "../src/components/communications/console";
import { NotificationCenter, DeliveryHistory } from "../src/components/communications/notification-center";
import { NotificationDrawer } from "../src/components/communications/notification-drawer";
import { MessageCard } from "../src/components/communications/thread";
import { projectCommunicationData } from "../src/lib/communications/input";
import { projectNotificationData } from "../src/lib/notifications/input";
import type { CommunicationData } from "../src/lib/communications/contracts";
import type { NotificationData } from "../src/lib/notifications/contracts";

const org = "00000000-0000-4000-8000-000000000001", thread = "00000000-0000-4000-8000-000000000002", team = "00000000-0000-4000-8000-000000000003", message = "00000000-0000-4000-8000-000000000004", attachment = "00000000-0000-4000-8000-000000000005";
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "communications-ui-test" };
function render(node: ReturnType<typeof createElement>) { return renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, node)); }
function fixture(overrides: Record<string, unknown> = {}): CommunicationData {
  const result = projectCommunicationData({ person: { id: org, label: "Controlled member" }, organizations: [{ id: org, label: "Controlled club" }], organizationId: org, features: { communications: true, announcements: true, team_chat: true }, operations: [], threads: [{ id: thread, organization_id: org, title: "Falcons chat", kind: "team_chat", version: 1, status: "active", unread_count: 2, operations: [] }], detail: { thread: { id: thread, organization_id: org, title: "Falcons chat", kind: "team_chat", version: 1, status: "active", operations: [] }, messages: [{ id: message, body: "Controlled private message", author_name: "Controlled coach", sequence: 1, version: 1, status: "visible", created_at: "2026-10-02T05:00:00Z", operations: [] }] }, targets: [{ scope_type: "team", scope_id: team, label: "Controlled Falcons", operations: ["thread.create", "announcement.send"] }], unread: { messages: 2, channels: 1 }, ...overrides }); assert.ok(result); return result;
}
function notifications(overrides: Record<string, unknown> = {}): NotificationData {
  const result = projectNotificationData({ notifications: [{ id: message, organization_id: org, category: "events", event_type: "event.rescheduled", title: "Practice moved", body: "Review the current schedule.", destination: `/app/calendar?org=${org}&event=${thread}`, created_at: "2026-10-02T05:00:00Z", read_at: null }], preferences: [], history: [], availability: { in_app: true, email: "not_configured", sms: "future", push: "future" }, unread_count: 7, features: { notifications: true, in_app_notifications: true }, operations: ["notification.read", "notification.read_all", "preference.set"], organizations: [{ id: org, label: "Controlled club" }], organizationId: org, ...overrides }); assert.ok(result); return result;
}
test("communications controls follow current row operations instead of role names", () => {
  const restricted = render(createElement(CommunicationsConsole, { data: fixture(), query: { view: "messages", organization_id: org, thread_id: thread } })); assert.match(restricted, /Controlled private message/); assert.doesNotMatch(restricted, /Send a message|Create conversation|Save conversation|Upload attachment|Report message|Pin<\/button>/);
  const editable = fixture({ detail: { thread: { id: thread, organization_id: org, title: "Falcons chat", kind: "team_chat", version: 1, status: "active", operations: ["message.send", "read.thread"] }, messages: [] } }); const html = render(createElement(CommunicationsConsole, { data: editable, query: { view: "messages", organization_id: org, thread_id: thread } })); assert.match(html, /Send a message/); assert.match(html, /Mark conversation read/); assert.doesNotMatch(html, /Conversation settings|Upload attachment/);
});
test("announcement audience controls contain only exact authorized target operations", () => {
  const data = fixture({ operations: ["announcement.send"], targets: [{ scope_type: "team", scope_id: team, label: "Controlled Falcons", operations: ["announcement.send"] }, { scope_type: "unit", scope_id: attachment, label: "Sibling unit", operations: ["thread.create"] }] }); const html = render(createElement(CommunicationsConsole, { data, query: { view: "announcements", organization_id: org } })); const audience = html.match(/<fieldset class="communication-choice-group">(.*?)<\/fieldset>/)?.[1]; assert.ok(audience); assert.match(audience, /Controlled Falcons/); assert.doesNotMatch(audience, /Sibling unit/); assert.match(html, /without sharing their private conversations or recipient lists/); assert.doesNotMatch(html, /recipient_email|primary_email|date_of_birth/);
});
test("disabled attachments and moderation do not advertise unavailable workflows", () => {
  const data = fixture({ features: { communications: true, attachments: false, moderation: false }, detail: { thread: { id: thread, organization_id: org, title: "Chat", kind: "team_chat", status: "active", operations: ["message.send", "attachment.intent"] }, messages: [] }, reports: [{ id: attachment, message_id: message, reason: "unsafe", status: "open", operations: ["report.moderate"] }] }); const html = render(createElement(CommunicationsConsole, { data, query: { view: "messages", organization_id: org } })); assert.doesNotMatch(html, /Upload private attachment|Record moderation decision/);
});
test("existing announcements can attach privately without exposing a conversational send control", () => {
  const data = fixture({ features: { communications: true, attachments: true }, detail: { thread: { id: thread, organization_id: org, title: "Team announcement", kind: "announcement", status: "active", operations: ["attachment.intent"] }, messages: [] } }); const html = render(createElement(CommunicationsConsole, { data, query: { view: "announcements", organization_id: org, thread_id: thread } })); assert.match(html, /Add a private attachment/); assert.match(html, /Upload attachment/); assert.doesNotMatch(html, /Send a message|Send message<\/button>/);
});
test("message rendering escapes untrusted HTML and removes hidden bodies and attachments", () => {
  const data = fixture({ detail: { thread: { id: thread, organization_id: org }, messages: [{ id: message, status: "visible", body: '<img src=x onerror="unsafe()">', author_name: "Name", operations: [] }, { id: attachment, status: "removed", body: "PRIVATE_REMOVED", attachments: [{ id: team, filename: "PRIVATE_FILE", operations: ["attachment.access"] }] }] } }); assert.ok(data.detail); const visible = render(createElement(MessageCard, { message: data.detail.messages[0] })); assert.match(visible, /&lt;img/); assert.doesNotMatch(visible, /<img/); const removed = render(createElement(MessageCard, { message: data.detail.messages[1] })); assert.match(removed, /This message was removed/); assert.doesNotMatch(removed, /PRIVATE_|Download privately/);
});
test("conversation detail retains a mobile back link and bounded older-message cursor", () => {
  const html = render(createElement(CommunicationsConsole, { data: fixture({ more: true, cursor: 5 }), query: { view: "messages", organization_id: org, thread_id: thread, query: "practice" } })); assert.match(html, /communication-mobile-back/); assert.match(html, /Back to conversations/); assert.match(html, /Older messages/); assert.match(html, /before=5/); assert.match(html, /q=practice/); assert.doesNotMatch(html, /object_name|signedUrl/);
});
test("notification center uses canonical unread count and inactive provider is explicit", () => {
  const html = render(createElement(NotificationCenter, { data: notifications(), query: { view: "preferences", organization_id: org } })); assert.match(html, /7 unread updates/); assert.match(html, /Email preferences are saved while delivery remains unconfigured/); assert.match(html, /value="in_app"/); assert.match(html, /value="email"/); assert.doesNotMatch(html, /value="sms"|value="push"|Send email|Process delivery queue/);
});
test("notification drawer exposes canonical count, dialog semantics and safe destination only", () => {
  const html = render(createElement(NotificationDrawer, { data: notifications() })); assert.match(html, /7 unread notifications/); assert.match(html, /aria-haspopup="dialog"/); assert.match(html, /<dialog/); assert.match(html, /aria-labelledby="boss-notification-heading"/); assert.match(html, /Mark all read/); assert.match(html, /View all notifications/); assert.match(html, /\/app\/calendar\?org=/);
  const disabled = render(createElement(NotificationDrawer, { data: notifications({ features: { in_app_notifications: false } }) })); assert.equal(disabled, "");
});
test("delivery history requires its projected permission and shows safe status without provider details", () => {
  const data = notifications({ operations: ["delivery.process"], history: [{ id: attachment, event_type: "payment.recorded", status: "sent", channel: "email", recipient_name: "Controlled adult", attempts: 1, created_at: "2026-10-02T05:00:00Z", raw_email: "PRIVATE_EMAIL", provider_reference: "PRIVATE_PROVIDER" }] }); const denied = render(createElement(NotificationCenter, { data, query: { view: "inbox", organization_id: org } })); assert.doesNotMatch(denied, />Delivery history<\/a>/); const history = render(createElement(DeliveryHistory, { data })); assert.match(history, /Provider acceptance is recorded as sent/); assert.match(history, /Controlled adult/); assert.doesNotMatch(history, /PRIVATE_|PRIVATE_EMAIL/);
});

test("group-only scope does not offer staff, coach or direct conversation kinds", () => {
  const data = fixture({ detail: null, operations: ["thread.create"], features: { communications: true, direct_messaging: true, team_chat: false }, targets: [{ scope_type: "team", scope_id: team, label: "Authorized family team", operations: ["thread.create"], thread_kinds: ["group"] }], candidates: [{ id: attachment, label: "Authorized guardian" }] });
  const html = render(createElement(CommunicationsConsole, { data, query: { view: "messages", organization_id: org } })); const kinds = html.match(/<select name="kind"[^>]*>(.*?)<\/select>/)?.[1]; assert.ok(kinds); assert.match(kinds, /value="group"/); assert.doesNotMatch(kinds, /value="coach_staff"|value="direct"|value="organization_staff"/); assert.match(html, /Authorized guardian/); assert.doesNotMatch(html, /primary_email|date_of_birth/);
});
test("group settings preserve current explicit members and add only projected choices", () => {
  const data = fixture({ candidates: [{ id: attachment, label: "Current candidate" }], detail: { thread: { id: thread, organization_id: org, title: "Controlled group", kind: "group", version: 2, status: "active", operations: ["thread.update"], members: [{ id: org, label: "Current actor" }, { id: team, label: "Existing group member" }] }, messages: [] } });
  const html = render(createElement(CommunicationsConsole, { data, query: { view: "messages", organization_id: org, thread_id: thread } })); assert.match(html, /Conversation members/); assert.match(html, /Existing group member/); assert.match(html, new RegExp(`name="members"[^>]*checked=""[^>]*value="${team}"|name="members"[^>]*value="${team}"[^>]*checked=""`)); assert.match(html, /Current candidate/); assert.doesNotMatch(html, new RegExp(`name="members"[^>]*value="${org}"`));
});
test("role audience picker filters catalog roles to exact authorized target scope", () => {
  const data = fixture({ operations: ["announcement.send"], audience_roles: [{ key: "head_coach", label: "Head coach", allowed_scope_types: ["team"] }, { key: "platform_administrator", label: "Platform role", allowed_scope_types: ["platform"] }] });
  const html = render(createElement(CommunicationsConsole, { data, query: { view: "announcements", organization_id: org } })); const roles = html.match(/<select name="role_key"[^>]*>(.*?)<\/select>/)?.[1]; assert.ok(roles); assert.match(roles, /Head coach/); assert.doesNotMatch(roles, /Platform role/); assert.doesNotMatch(html, /recipient_email|auth_user_id/);
});
