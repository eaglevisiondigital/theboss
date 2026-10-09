import assert from "node:assert/strict";
import test from "node:test";
import { parseNotificationCommand, parseNotificationQuery, safeNotificationDestination as safeInboxDestination } from "../src/lib/notifications/input";
import { safeNotificationDestination as safeEmailDestination, renderNotificationEmail } from "../src/lib/notifications/templates";

const org = "ab77c499-33b5-4a51-8e39-1fe74d12c5d2";
const resource = "ba458084-ea82-4814-8c2a-859166610d42";
const attendance = `/app/attendance?org=${org}&event=${resource}&occurrence=2026-10-03T18%3A00%3A00`;
const volunteers = `/app/volunteers?org=${org}&shift=${resource}`;

test("attendance and volunteer destinations are finite current-record links", () => {
  for (const destination of [attendance, volunteers, `/app/volunteers?org=${org}&event=${resource}`]) {
    assert.equal(safeInboxDestination(destination), destination);
    assert.equal(safeEmailDestination(destination), true);
    const template = renderNotificationEmail({ title: "Review your commitment", summary: "Review the current record in Boss.", destination }, "https://thebossplatform.netlify.app");
    assert.ok(template.text.includes(destination));
  }
});

test("coordination links reject foreign destinations, forged fields and duplicate resources", () => {
  for (const destination of [
    `https://evil.example${attendance}`, `${attendance}&org=${org}`, `${volunteers}&shift=${resource}`,
    `${volunteers}&person=${resource}`, `${volunteers}&event=${resource}`, `${attendance}&reason=private`, `${attendance}&redirect=https://evil.example`,
    `/app/attendance?org=${org}&event=${resource}`, `/app/volunteers?org=${org}&shift=invalid`,
    `${attendance}#private`, attendance.replace("2026-10-03", "2026-02-30"), attendance.replace("18%3A00", "25%3A00"),
  ]) {
    assert.equal(safeInboxDestination(destination), null, destination);
    assert.equal(safeEmailDestination(destination), false, destination);
  }
});

test("coordination categories retain independently scoped preferences", () => {
  for (const category of ["attendance", "volunteers"]) {
    assert.ok(parseNotificationCommand({ operation: "preference.set", input: { category, channel: "in_app", organization_id: org, enabled: false } }));
    assert.equal(parseNotificationQuery({ category })?.category, category);
  }
  assert.equal(parseNotificationCommand({ operation: "preference.set", input: { category: "stats", channel: "in_app", enabled: true } }), null);
});
