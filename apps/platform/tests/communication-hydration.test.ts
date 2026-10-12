import test from "node:test";
import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToString } from "react-dom/server";
import { NotificationCard, DeliveryHistory } from "../src/components/communications/notification-center";
import { MessageCard } from "../src/components/communications/thread";
import { emptyNotifications, type Notification } from "../src/lib/notifications/contracts";

const notification: Notification = {
  id: "90000000-0000-4000-8000-000000000010", category: "communications",
  event_type: "merchant.offer_review", title: "Synthetic update", body: "Synthetic body",
  destination: null, organization_id: null, team_id: null,
  created_at: "2026-10-09T13:00:00Z", read_at: null,
};

function renderAcrossTimezones(createdAt: string) {
  const previous = process.env.TZ;
  try {
    return ["UTC", "America/Los_Angeles", "Pacific/Auckland"].map(timeZone => {
      process.env.TZ = timeZone;
      return renderToString(createElement(NotificationCard, {
        notification: { ...notification, created_at: createdAt }, canRead: false,
      }));
    });
  } finally {
    if (previous === undefined) delete process.env.TZ;
    else process.env.TZ = previous;
  }
}

test("shared notification markup is identical across server and first hydration timezones", () => {
  for (const timestamp of [notification.created_at, "2026-10-09T01:00:00Z", "2026-03-08T09:30:00Z", "2026-11-01T08:30:00Z"]) {
    const markup = renderAcrossTimezones(timestamp);
    assert.equal(markup[1], markup[0]);
    assert.equal(markup[2], markup[0]);
    assert.ok(markup[0].includes(`dateTime="${timestamp}"`));
    assert.match(markup[0], /UTC/);
  }
});

test("invalid notification timestamps remain empty and do not crash rendering", () => {
  const markup = renderAcrossTimezones("not-a-date");
  assert.equal(markup[1], markup[0]);
  assert.match(markup[0], /<time dateTime="not-a-date"><\/time>/);
  assert.doesNotMatch(markup[0], /Invalid Date/);
});

test("message and delivery timestamps share stable markup without changing their original instants", () => {
  const previous = process.env.TZ;
  try {
    const markup = ["UTC", "America/Los_Angeles", "Pacific/Auckland"].map(timeZone => {
      process.env.TZ = timeZone;
      return renderToString(createElement(MessageCard, { message: {
        id: notification.id, body: "Synthetic message", author_name: "Synthetic author",
        author_person_id: null, sequence: 1, version: 1, created_at: notification.created_at,
        edited_at: notification.created_at, status: "active", pinned: false, operations: [], attachments: [],
      }})) + renderToString(createElement(DeliveryHistory, { data: {
        ...emptyNotifications, history: [{ id: notification.id, event_type: "synthetic",
          channel: "in_app", status: "sent", created_at: notification.created_at,
          sent_at: notification.created_at, failure_category: null, attempts: 1, recipient_name: "Synthetic recipient" }],
      }}));
    });
    assert.equal(markup[1], markup[0]);
    assert.equal(markup[2], markup[0]);
    assert.equal(markup[0].split(`dateTime="${notification.created_at}"`).length - 1, 4);
  } finally {
    if (previous === undefined) delete process.env.TZ;
    else process.env.TZ = previous;
  }
});
