import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { NotificationCenter } from "../src/components/communications/notification-center";
import { NotificationDrawer } from "../src/components/communications/notification-drawer";
import { emptyNotifications, type NotificationQuery } from "../src/lib/notifications/contracts";
import { readNotifications } from "../src/lib/notifications/read";

const org = "00000000-0000-4000-8000-000000000001", notification = "00000000-0000-4000-8000-000000000002";
const query: NotificationQuery = { view: "inbox", organization_id: org, category: "attendance", limit: 30 };
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "notification-data-test" };
function render(node: ReturnType<typeof createElement>) { return renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, node)); }
const authorizedData = {
  ...emptyNotifications,
  notifications: [{ id: notification, organization_id: org, category: "attendance", event_type: "attendance.requested", title: "Controlled attendance request", body: "Review your response in Boss.", destination: null, created_at: "2026-10-03T13:00:00Z", read_at: null }],
  unread_count: 1,
  operations: ["notification.read", "notification.read_all", "preference.set"],
  availability: { ...emptyNotifications.availability, in_app: true },
  features: { notifications: true, in_app_notifications: true },
  organizations: [{ id: org, label: "Controlled organization" }],
  organizationId: org,
};
const privateData = {
  ...authorizedData,
  notifications: [{ ...authorizedData.notifications[0], title: "PRIVATE_NOTIFICATION", body: "PRIVATE_BODY" }],
  organizations: [{ id: org, label: "PRIVATE_ORGANIZATION" }],
  operations: ["notification.read", "notification.read_all", "preference.set", "delivery.process", "reminder.generate"],
  preferences: [{ id: notification, channel: "in_app", category: "attendance", organization_id: org, team_id: null, enabled: true }],
  history: [{ id: notification, event_type: "attendance.requested", channel: "in_app", status: "sent", created_at: "2026-10-03T13:00:00Z", sent_at: null, failure_category: null, attempts: 1, recipient_name: "PRIVATE_RECIPIENT" }],
};

test("restricted notification read renders denial and discards every record and action", async () => {
  let calls = 0;
  const data = await readNotifications(query, async request => {
    calls++;
    assert.deepEqual(request, { p_query: query });
    return { data: privateData, error: { code: "PT403", message: "PRIVATE_DATABASE_DETAIL" } };
  });
  assert.equal(calls, 1);
  assert.deepEqual(data, { ...emptyNotifications, accessDenied: true });
  const html = render(createElement(NotificationCenter, { data, query }));
  assert.match(html, /Notifications are restricted in this organization context/);
  assert.doesNotMatch(html, /temporarily unavailable|PRIVATE_|Mark read|Mark all read|Save preference|Notification administration|Process delivery queue/);
  assert.equal(render(createElement(NotificationDrawer, { data })), "");
});

test("notification timeout, authentication and request failures retain safe outage handling", async () => {
  for (const code of ["57014", "PT401", "PT422", "PGRST301", "500", "PT403_SUFFIX"]) {
    const data = await readNotifications(query, async () => ({ data: privateData, error: { code, message: "PRIVATE_DATABASE_DETAIL" } }));
    assert.deepEqual(data, { ...emptyNotifications, unavailable: true });
    const html = render(createElement(NotificationCenter, { data, query }));
    assert.match(html, /Notifications are temporarily unavailable/);
    assert.doesNotMatch(html, /restricted in this organization context|PRIVATE_|Mark read|Save preference/);
  }
});

test("notification transport exceptions and malformed projections stay unavailable without error disclosure", async () => {
  for (const failure of ["throw", "malformed"] as const) {
    let calls = 0;
    const data = await readNotifications(query, async () => {
      calls++;
      if (failure === "throw") throw new TypeError("PRIVATE_NETWORK_DETAIL");
      return { data: { ...privateData, notifications: null }, error: null };
    });
    assert.equal(calls, 1);
    assert.deepEqual(data, { ...emptyNotifications, unavailable: true });
    const html = render(createElement(NotificationCenter, { data, query }));
    assert.match(html, /Notifications are temporarily unavailable/);
    assert.doesNotMatch(html, /restricted in this organization context|PRIVATE_/);
  }
});

test("successful notification read preserves canonical count, organization and safe projected controls", async () => {
  const data = await readNotifications(query, async () => ({ data: { ...authorizedData, raw_error: "PRIVATE_UNPROJECTED" }, error: null }));
  assert.equal(data.unread_count, 1);
  assert.equal(data.organizationId, org);
  assert.equal(data.accessDenied, undefined);
  assert.equal(data.unavailable, undefined);
  const html = render(createElement(NotificationCenter, { data, query }));
  assert.match(html, /Controlled attendance request|Controlled organization|Mark read/);
  assert.doesNotMatch(html, /temporarily unavailable|restricted in this organization context|PRIVATE_/);
  assert.match(render(createElement(NotificationDrawer, { data })), /1 unread notifications/);
});

test("successful feature-disabled notification projection remains distinct from denial and outage", async () => {
  const data = await readNotifications({ view: "summary", limit: 5 }, async () => ({ data: { ...emptyNotifications, operations: ["preference.set"] }, error: null }));
  assert.equal(data.availability.in_app, false);
  assert.equal(data.accessDenied, undefined);
  assert.equal(data.unavailable, undefined);
  assert.equal(render(createElement(NotificationDrawer, { data })), "");
  const html = render(createElement(NotificationCenter, { data, query: { view: "preferences" } }));
  assert.match(html, /Notification preferences|Save preference/);
  assert.doesNotMatch(html, /temporarily unavailable|restricted in this organization context/);
});

test("denied filtered inbox does not replace a separately authorized global header summary", async () => {
  const [summary, inbox] = await Promise.all([
    readNotifications({ view: "summary", limit: 5 }, async request => {
      assert.deepEqual(request, { p_query: { view: "summary", limit: 5 } });
      return { data: authorizedData, error: null };
    }),
    readNotifications(query, async () => ({ data: privateData, error: { code: "PT403" } })),
  ]);
  assert.match(render(createElement(NotificationDrawer, { data: summary })), /1 unread notifications/);
  const html = render(createElement(NotificationCenter, { data: inbox, query }));
  assert.match(html, /Notifications are restricted in this organization context/);
  assert.doesNotMatch(html, /Controlled attendance request|PRIVATE_|temporarily unavailable/);
});
