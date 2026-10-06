import Link from "next/link";
import type { TournamentBracket, TournamentMatch, TournamentSeed } from "@/lib/tournaments/contracts";

const when = (value: string | null) => value ? new Intl.DateTimeFormat("en-US", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : null;

export function TournamentBracketView({ bracket, seeds, matches }: { bracket: TournamentBracket; seeds: TournamentSeed[]; matches: TournamentMatch[] }) {
  const rounds = Array.from(new Set(matches.map((match) => match.round_number))).sort((left, right) => left - right);
  const entryName = (entryId: string | null) => seeds.find((seed) => seed.entry_id === entryId)?.name ?? "Confirmed entry";
  const placements = [
    ["Champion", bracket.champion_entry_id],
    ["Runner-up", bracket.runner_up_entry_id],
    ["Third", bracket.third_entry_id],
    ["Fourth", bracket.fourth_entry_id],
  ].filter((placement): placement is [string, string] => Boolean(placement[1]));

  return <section className="admin-section tournament-bracket" aria-labelledby="bracket-heading">
    <div className="game-card-heading"><div><h2 id="bracket-heading">{bracket.name}</h2><p>{bracket.status} · revision {bracket.current_revision} · {bracket.bracket_size} team single elimination</p></div>{bracket.champion_entry_id && <strong>Champion: {entryName(bracket.champion_entry_id)}</strong>}</div>
    {placements.length > 0 && <section aria-labelledby="placements-heading"><h3 id="placements-heading">Final placements</h3><ol className="tournament-seeds">{placements.map(([label, entryId]) => <li key={label}><strong>{label}:</strong> {entryName(entryId)}</li>)}</ol></section>}
    <details><summary>Accepted seed snapshot</summary><ol className="tournament-seeds">{seeds.map((seed) => <li key={seed.id}><strong>{seed.seed}.</strong> {seed.name}{seed.source_rank ? ` · source rank ${seed.source_rank}` : ""}{seed.source_generation ? ` · generation ${seed.source_generation}` : ""}{seed.override_reason ? ` · ${seed.override_reason}` : ""}</li>)}</ol></details>
    <div className="tournament-rounds">{rounds.map((round) => <section className="tournament-round" key={round}><h3>{matches.find((match) => match.round_number === round)?.stage_name ?? `Round ${round}`}</h3>{matches.filter((match) => match.round_number === round).map((match) => <article className="tournament-match" key={match.id}><div className="game-card-heading"><strong>{match.label}</strong><span>{match.status.replaceAll("_", " ")}</span></div><p>{match.primary_name ?? (match.primary_source_kind === "bye" ? "Bye" : "Winner / qualifier pending")} <span aria-hidden="true">vs</span> {match.opponent_name ?? (match.opponent_source_kind === "bye" ? "Bye" : "Winner / qualifier pending")}</p>{match.advancement_destination && <p>Winner advances to {match.advancement_destination}.</p>}{match.game_id ? <><p>{when(match.start_at)}{match.venue_label ? ` · ${match.venue_label}` : ""}</p><p>{match.game_status}{match.game_status === "final" ? ` · ${match.primary_score ?? 0}–${match.opponent_score ?? 0}` : ""}</p><Link href={`/app/games?game=${match.game_id}`}>Open Game Center</Link></> : <p>{match.status === "ready" ? "Ready for a canonical Calendar / Game Center link." : "Waiting on the explicit slot dependency."}</p>}</article>)}</section>)}</div>
  </section>;
}
