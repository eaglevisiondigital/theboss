import assert from "node:assert/strict";
import test from "node:test";
import { dispatchEmailDelivery, type DeliveryCompletion, type DeliveryRepository, type EmailDeliveryClaim } from "../src/lib/notifications/delivery";
import { configuredEmailProvider, SyntheticEmailProvider, type EmailProvider } from "../src/lib/notifications/email";
import { renderNotificationEmail, safeNotificationDestination, stableDeliveryKey } from "../src/lib/notifications/templates";

const id = "5c9fe87c-a0bb-4fd7-8358-44b60527426e";
const org = "ab77c499-33b5-4a51-8e39-1fe74d12c5d2";
const source = "ba458084-ea82-4814-8c2a-859166610d42";
const template = renderNotificationEmail({ title: "Event changed", summary: "Review your calendar.", destination: `/app/calendar?org=${org}&event=${source}` }, "https://thebossplatform.netlify.app");
class FakeRepository implements DeliveryRepository {
  state: DeliveryCompletion = { status: "queued" };
  attempts = 0;
  generation = 0;
  authorized = true;
  enabled = true;
  mandatory = false;
  recovered = false;
  rejectFinish = false;
  async claim(deliveryId: string, now: number): Promise<EmailDeliveryClaim | null> {
    if (deliveryId !== id || this.state.status !== "queued" || (this.state.nextAttemptAt ?? 0) > now) return null;
    this.state = { status: "processing" };
    return { id, generation: ++this.generation, attempt: ++this.attempts, recoveredExpiredLease: this.recovered, sourceAuthorized: this.authorized, preferenceEnabled: this.enabled, mandatory: this.mandatory, request: { to: "synthetic@boss-test.example.invalid", template } };
  }
  async finish(deliveryId: string, generation: number, completion: DeliveryCompletion): Promise<boolean> {
    if (this.rejectFinish || deliveryId !== id || generation !== this.generation) return false;
    this.state = completion;
    return true;
  }
}
test("production email is explicitly not configured", () => assert.equal(configuredEmailProvider(), null));
test("provider acceptance records sent without inventing delivery", async () => {
  const repository = new FakeRepository(); const provider = new SyntheticEmailProvider();
  assert.equal(await dispatchEmailDelivery(id, repository, provider, 100), "updated");
  assert.equal(repository.state.status, "sent"); assert.equal(repository.state.sentAt, 100); assert.equal(provider.acceptedCount, 1);
  assert.equal(await dispatchEmailDelivery(id, repository, provider, 200), "skipped"); assert.equal(provider.acceptedCount, 1);
});
test("simultaneous workers claim one delivery", async () => {
  const repository = new FakeRepository(); const provider = new SyntheticEmailProvider();
  const results = await Promise.all([dispatchEmailDelivery(id, repository, provider, 100), dispatchEmailDelivery(id, repository, provider, 100)]);
  assert.deepEqual(results.sort(), ["skipped", "updated"]); assert.equal(provider.acceptedCount, 1);
});
test("authority removal suppresses before provider send", async () => {
  const repository = new FakeRepository(); repository.authorized = false; const provider = new SyntheticEmailProvider();
  await dispatchEmailDelivery(id, repository, provider, 100); assert.deepEqual(repository.state, { status: "suppressed", failureCategory: "authority_removed" }); assert.equal(provider.attempts, 0);
});
test("optional preference suppresses email", async () => {
  const repository = new FakeRepository(); repository.enabled = false; const provider = new SyntheticEmailProvider();
  await dispatchEmailDelivery(id, repository, provider, 100); assert.equal(repository.state.failureCategory, "preference"); assert.equal(provider.attempts, 0);
});
test("fixed internal mandatory policy bypasses preference only", async () => {
  const repository = new FakeRepository(); repository.enabled = false; repository.mandatory = true; const provider = new SyntheticEmailProvider();
  await dispatchEmailDelivery(id, repository, provider, 100); assert.equal(repository.state.status, "sent");
  const removed = new FakeRepository(); removed.enabled = false; removed.mandatory = true; removed.authorized = false;
  await dispatchEmailDelivery(id, removed, provider, 100); assert.equal(removed.state.failureCategory, "authority_removed");
});
test("missing provider records a truthful suppressed state", async () => {
  const repository = new FakeRepository(); await dispatchEmailDelivery(id, repository, null, 100);
  assert.deepEqual(repository.state, { status: "suppressed", failureCategory: "not_configured" });
});
test("transient failure waits for backoff then retries stable work", async () => {
  const repository = new FakeRepository(); const provider = new SyntheticEmailProvider(["transient"]);
  await dispatchEmailDelivery(id, repository, provider, 100); assert.equal(repository.state.status, "queued"); assert.equal(repository.state.nextAttemptAt, 60_100);
  assert.equal(await dispatchEmailDelivery(id, repository, provider, 60_099), "skipped");
  await dispatchEmailDelivery(id, repository, provider, 60_100); assert.equal(repository.state.status, "sent"); assert.equal(provider.acceptedCount, 1); assert.equal(repository.attempts, 2);
});
test("five transient failures exhaust bounded retries", async () => {
  const repository = new FakeRepository(); const provider = new SyntheticEmailProvider(["transient", "transient", "transient", "transient", "transient"]);
  for (let attempt = 0; attempt < 5; attempt++) await dispatchEmailDelivery(id, repository, provider, repository.state.nextAttemptAt ?? 100);
  assert.equal(repository.state.status, "failed"); assert.equal(repository.state.failureCategory, "attempts_exhausted"); assert.equal(provider.attempts, 5);
  assert.equal(await dispatchEmailDelivery(id, repository, provider, 1e12), "skipped");
});
test("permanent failure never retries", async () => {
  const repository = new FakeRepository(); const provider = new SyntheticEmailProvider(["permanent"]);
  await dispatchEmailDelivery(id, repository, provider, 100); assert.equal(repository.state.failureCategory, "permanent");
  assert.equal(await dispatchEmailDelivery(id, repository, provider, 1e12), "skipped");
});
test("ambiguous provider outcome requires idempotency", async () => {
  const repository = new FakeRepository(); const provider: EmailProvider = { supportsIdempotency: false, send: async () => ({ accepted: false, category: "ambiguous" }) };
  await dispatchEmailDelivery(id, repository, provider, 100); assert.equal(repository.state.status, "failed"); assert.equal(repository.state.failureCategory, "ambiguous");
});
test("throwing provider has safe ambiguous classification", async () => {
  const repository = new FakeRepository(); const provider: EmailProvider = { supportsIdempotency: false, send: async () => { throw new Error("Do not record provider internals"); } };
  await dispatchEmailDelivery(id, repository, provider, 100); assert.deepEqual(repository.state, { status: "failed", failureCategory: "ambiguous" });
});
test("expired lease without idempotency does not send again", async () => {
  const repository = new FakeRepository(); repository.recovered = true; let sends = 0;
  await dispatchEmailDelivery(id, repository, { supportsIdempotency: false, send: async () => { sends++; return { accepted: true, providerReference: "accepted" }; } }, 100);
  assert.equal(repository.state.failureCategory, "ambiguous"); assert.equal(sends, 0);
});
test("accepted-provider crash retries same key and reference", async () => {
  const repository = new FakeRepository(); const provider = new SyntheticEmailProvider(); repository.rejectFinish = true;
  assert.equal(await dispatchEmailDelivery(id, repository, provider, 100), "stale");
  repository.rejectFinish = false; repository.recovered = true; repository.state = { status: "queued" };
  await dispatchEmailDelivery(id, repository, provider, 200); assert.equal(repository.state.providerReference, "synthetic-1"); assert.equal(provider.acceptedCount, 1); assert.equal(provider.attempts, 2);
});
test("provider empty or excessive reference is not trusted", async () => {
  for (const providerReference of ["", "x".repeat(201)]) {
    const repository = new FakeRepository(); await dispatchEmailDelivery(id, repository, { supportsIdempotency: true, send: async () => ({ accepted: true, providerReference }) }, 100);
    assert.equal(repository.state.failureCategory, "ambiguous");
  }
});
test("synthetic adapter refuses real email destinations", async () => {
  await assert.rejects(new SyntheticEmailProvider().send({ to: "customer@example.com", idempotencyKey: "synthetic", template }), /reserved invalid/);
});
test("stable delivery key normalizes UUID and refuses arbitrary keys", () => {
  assert.equal(stableDeliveryKey(id.toUpperCase()), stableDeliveryKey(id)); assert.throws(() => stableDeliveryKey("forged"));
});
test("template escapes all untrusted text", () => {
  const output = renderNotificationEmail({ title: "<script>x</script>", summary: 'A & B "quoted"', organizationName: "<img src=x>", destination: `/app/messages?org=${org}&thread=${source}` }, "https://thebossplatform.netlify.app");
  assert.ok(output.html.includes("&lt;script&gt;")); assert.ok(!output.html.includes("<script>")); assert.ok(output.text.includes("<script>x</script>")); assert.ok(output.html.includes("&amp; B &quot;"));
});
for (const value of ["https://evil.example/", "/app/messages?org=x&thread=y", `/app/calendar?org=${org}&event=${source}&redirect=https://evil.example`, "//evil.example", "/app/registrations?view=admin"]) {
  test(`destination refuses ${value.slice(0, 45)}`, () => assert.equal(safeNotificationDestination(value), false));
}
test("template rejects subject injection and external origins", () => {
  const input = { title: "Notice\r\nBCC: user", summary: "Review Boss", destination: `/app/calendar?org=${org}&event=${source}` };
  assert.throws(() => renderNotificationEmail(input, "https://thebossplatform.netlify.app"));
  for (const origin of ["http://boss.example", "https://boss.example/path", "https://user:password@boss.example", "https://boss.example?x=1"]) assert.throws(() => renderNotificationEmail({ ...input, title: "Notice" }, origin));
});
test("calendar CTA accepts an actual day and rejects impossible dates", () => {
  const base = `/app/calendar?org=${org}&event=${source}`;
  assert.equal(safeNotificationDestination(`${base}&date=2026-10-02`), true);
  assert.equal(safeNotificationDestination(`${base}&date=2026-02-30`), false);
  assert.equal(safeNotificationDestination(`${base}&date=2026-13-01`), false);
});

test("calendar CTA preserves moved occurrence with canonical encoded timezone", () => {
  const base = `/app/calendar?org=${org}&event=${source}&date=2026-10-02`;
  assert.equal(safeNotificationDestination(`${base}&tz=America%2FChicago&occurrence=2026-10-03T23%3A30%3A00`), true);
  assert.equal(safeNotificationDestination(`${base}&tz=Etc%2FGMT%2B5&occurrence=2026-10-03T23%3A30%3A00`), true);
  assert.equal(safeNotificationDestination(`${base}&tz=Not%2FAZone&occurrence=2026-10-03T23%3A30%3A00`), false);
  assert.equal(safeNotificationDestination(`${base}&tz=UTC&occurrence=2026-02-30T23%3A30%3A00`), false);
  assert.equal(safeNotificationDestination(`${base}&tz=UTC&occurrence=2026-10-03T24%3A00%3A00`), false);
  assert.equal(safeNotificationDestination(`${base}&occurrence=2026-10-03T23%3A30%3A00`), false);
});
