"use client";
import type { RankingQuery } from "@/lib/rankings/contracts";
import { RankingActionForm } from "./action-form";
export function RankingRebuild({ query }: { query: RankingQuery }) {
  return <RankingActionForm label="Rebuild / continue this scope" build={() => query.edition_id && query.product ? { action: "ranking.rebuild", input: { edition_id: query.edition_id, product: query.product, ...(query.definition_id ? { definition_id: query.definition_id } : {}), ...(query.group_id ? { group_id: query.group_id } : {}) } } : null} />;
}
