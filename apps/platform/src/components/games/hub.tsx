import Link from "next/link";
import type { GameData, GameQuery } from "@/lib/games/contracts";
import { GameCard, gameHref } from "./presentation";
export function GameHub({ data, query, family = false }: { data: GameData; query: GameQuery; family?: boolean }) {
  if (data.unavailable || data.restricted || data.features.game_center !== true || !data.games.length) return null;
  const next = data.games.filter(game => !["canceled", "abandoned"].includes(game.status)).slice(0, 3);
  if (!next.length) return null;
  return <section className="game-hub admin-section" aria-label={family ? "Family games" : "Your games"}><div className="section-heading"><h2>{family ? "Family games" : "Your next games"}</h2><p>Current matchups and results from your authorized teams.</p></div><div className="game-cards">{next.map(game => <GameCard key={game.id} compact game={game} query={query} />)}</div><Link className="card-link" href={gameHref(query)}>Open Game Center</Link></section>;
}
