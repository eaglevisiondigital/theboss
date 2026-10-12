import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadGames } from "@/lib/games/data";
import { gameConsoleKey, parseGameQuery } from "@/lib/games/input";
import { GameConsole } from "@/components/games/console";
export const metadata: Metadata = { title: "Game Center" };
export const dynamic = "force-dynamic";
export default async function GamesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/games"); const params = await searchParams, query = parseGameQuery(params);
  if (!query) return <p className="form-notice" role="status">Review the game filters and date range, then try again.</p>;
  const data = await loadGames(query, params.from === undefined && params.to === undefined);
  return <GameConsole key={gameConsoleKey(query, params)} data={data} query={query} />;
}
