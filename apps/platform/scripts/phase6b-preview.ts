// Synthetic local layout evidence. No Auth client, backend or RPC.
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { RankingsHub } from "../src/components/rankings/hub";
import { projectRankings } from "../src/lib/rankings/input";
import type { RankingProduct } from "../src/lib/rankings/contracts";
const css = readFileSync("src/app/globals.css", "utf8"), id = "10000000-0000-0000-0000-000000000001";
function frame(product: RankingProduct) {
  const data = projectRankings({ contract: "rankings-v1", freshness: "current", generation: 7, rows: [{ id, label: "CONTROLLED TEST Falcons athlete with a long name", rank: 1, wins: 3, losses: 1, ties: 1, points: 10, win_percentage: 0.7, scoring_for: 40, scoring_against: 20, value: 0.3125, qualification_state: "qualified", current_holder: product === "records", achieved_at: "2026-09-12T18:15:00Z", recognized_at: "2026-10-05T18:15:00Z", event_type: "recognized", qualification: { thresholds: [{ type: "min_pa", minimum: 10, actual: 12, passed: true }] }, coverage: { complete_games: 4, source_games: 4, partial_allowed: false }, source_manifest: { sport_key: "baseball", stat_definition_version: "intelligence-v1", sources: [{ epoch: 2 }] }, explanation: { state: "unresolved_tie", steps: [{ rule: { type: "head_to_head" }, applicable: true, result: "remaining_tied", values: [{ value: 1 }, { value: 1 }] }] } }] });
  if (!data) throw new Error("Synthetic fixture invalid");
  const html = renderToStaticMarkup(createElement(RankingsHub, { data, query: { edition_id: id, product, ...(product !== "standings" ? { definition_id: id } : {}) } }));
  return `<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><title>Boss synthetic ${product}</title><style>${css}</style><body class="authenticated-page admin-shell"><main class="app-main container">${html}</main></body>`;
}
createServer((req, res) => { const url = new URL(req.url ?? "/", "http://127.0.0.1:4188"); res.setHeader("Content-Type", "text/html; charset=utf-8"); if (url.pathname === "/frame") { const p = url.searchParams.get("product"); res.end(frame(p === "leaderboard" || p === "records" ? p : "standings")); return; } res.end(`<!doctype html><title>Boss Phase 6B local responsive evidence</title>${["standings", "leaderboard", "records"].map(p => [1280, 768, 390, 320].map(w => `<h2>${p} ${w}px</h2><iframe title="${p} ${w}" width="${w}" height="820" src="/frame?product=${p}" style="border:0;display:block"></iframe>`).join("")).join("")}`); }).listen(4188, "127.0.0.1", () => console.info("Synthetic Phase 6B layout preview ready on loopback port 4188."));
