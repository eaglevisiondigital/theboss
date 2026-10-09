import Link from "next/link";
import type { Game, GameQuery } from "@/lib/games/contracts";
import { displayInstant, humanize } from "../coordination/presentation";
import { localDateTime } from "@/lib/calendar/temporal";
export function gameHref(query: Partial<GameQuery>, changes: Partial<GameQuery> = {}) {
  const names: Record<string, string> = { organization_id: "org", game_id: "game", team_id: "team", unit_id: "unit", season_id: "season", child_person_id: "child" }, params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...query, ...changes })) if (typeof value === "string" && value) params.set(names[key] ?? key, value);
  return `/app/games?${params.toString()}`;
}
export const currentCalendarKey = (game: Game) => game.occurrence_mode === "single" ? localDateTime(game.start_at, game.timezone) : game.occurrence_key;
export function calendarGameHref(game: Game) { return `/app/calendar?${new URLSearchParams({ org: game.organization_id, event: game.event_id, occurrence: currentCalendarKey(game), date: localDateTime(game.start_at, game.timezone).slice(0, 10), tz: game.timezone, view: "day" })}`; }
export function GameScore({ game }: { game: Game }) {
  const final = game.status === "final";
  return <div className="game-score" aria-label={`${game.primary.label} ${final ? game.primary.final_score ?? game.primary.score : game.primary.score}, ${game.opponent.label} ${final ? game.opponent.final_score ?? game.opponent.score : game.opponent.score}`}><div className="game-side"><span>{game.primary.label}</span><strong>{final ? game.primary.final_score ?? game.primary.score : game.primary.score}</strong><small>{game.home_away === "neutral" ? "Neutral site" : game.home_away === "home" ? "Home" : "Away"}</small></div><span className="game-score-divider" aria-hidden="true">:</span><div className="game-side"><span>{game.opponent.label}</span><strong>{final ? game.opponent.final_score ?? game.opponent.score : game.opponent.score}</strong><small>{game.home_away === "neutral" ? "Neutral site" : game.home_away === "home" ? "Away" : "Home"}</small></div></div>;
}
export function GameCard({ game, query, compact = false }: { game: Game; query?: Partial<GameQuery>; compact?: boolean }) {
  return <article className={`game-card${compact ? " game-card-compact" : ""}`}><div className="game-card-heading"><span className={`game-status game-status-${game.status}`}>{humanize(game.status)}</span><span className="game-sport">{game.sport_label}</span></div><h3>{game.title}</h3><GameScore game={game} /><p className="game-schedule"><time dateTime={game.start_at}>{displayInstant(game.start_at, game.timezone)}</time><span>{game.venue_label ?? "Venue to be confirmed"}</span></p>{game.reopened && <p className="game-attention">Reopened for correction</p>}<Link href={gameHref({ ...query, organization_id: game.organization_id, game_id: game.id })} className="card-link">View game</Link></article>;
}
