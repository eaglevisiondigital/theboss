// Synthetic rendered layout evidence only. No Auth, database, RPC or provider.
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { AchievementHub } from "../src/components/achievements/hub";
import { AchievementBadges } from "../src/components/achievements/badges";
import { emptyAchievements } from "../src/lib/achievements/input";
import type { AchievementCard } from "../src/lib/achievements/input";
const id = "10000000-0000-0000-0000-000000000001", css = readFileSync("src/app/globals.css", "utf8");
const router = { bfcacheId: "phase6e-layout", back() {}, forward() {}, push() {}, replace() {}, refresh() {}, prefetch() {} };
const cards: AchievementCard[] = ["current", "historical", "processing", "corrected", "revoked", "unavailable"].map((state, i) => ({ id: `10000000-0000-0000-0000-${String(i + 1).padStart(12, "0")}`, achievement_id: id, name: "CONTROLLED TEST verified multi-sport accomplishment with a long descriptive title", title: "Synthetic recognition", category: i ? "statistical_milestone" : "record", subject_type: "athlete", sport_key: "basketball", state, verification_level: i === 4 ? "organization_verified" : "boss_verified", achieved_at: "2026-10-06T12:00:00Z", recognized_at: "2026-10-06T12:01:00Z", badge_icon: "medal", tier: "gold", current: state === "current", current_holder: !i, co_holder: !i, show_on_profile: true, show_on_showcase: false, showcase_eligible: Boolean(i) }));
function frame(view: string) {
  const data = { ...emptyAchievements(), recognitions: cards, can_manage: true, can_issue: true, can_approve: true, definitions: [{ id, status: "active", version: 1, revision: { name: "CONTROLLED TEST canonical career threshold", source_kind: "athlete_career", revision: 1 } }], catalog: { teams: [{ id, name: "CONTROLLED TEST Falcons" }], profiles: [{ id, name: "CONTROLLED TEST Child One" }] }, history: [{ event_type: "recognized", state: "current", version: 1, created_at: "2026-10-06T12:01:00Z" }, { event_type: "corrected", state: "corrected", version: 2, created_at: "2026-10-06T12:02:00Z" }] };
  const element = view === "management" ? createElement(AchievementHub, { data, organizationId: id }) : createElement(AchievementBadges, { items: cards });
  const html = renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, element)).replaceAll("<details>", "<details open>");
  return `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Boss synthetic achievement ${view}</title><style>${css}</style></head><body class="authenticated-page admin-shell"><main class="app-main container"><h1>Phase 6E synthetic ${view}</h1>${html}</main></body></html>`;
}
createServer((req, res) => { const url = new URL(req.url ?? "/", "http://127.0.0.1:4191"); res.setHeader("Content-Type", "text/html; charset=utf-8"); res.end(frame(url.searchParams.get("view") ?? "management")); }).listen(4191, "127.0.0.1", () => console.info("Synthetic Phase 6E layout preview ready on loopback port 4191."));
