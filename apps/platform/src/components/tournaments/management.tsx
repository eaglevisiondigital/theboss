"use client";

import { useRouter } from "next/navigation";
import type { TournamentData } from "@/lib/tournaments/contracts";
import { TournamentActionForm } from "./action-form";

const read = (form: FormData, key: string) => String(form.get(key) ?? "").trim();

export function TournamentManagement({ data, editionId, bracketId }: { data: TournamentData; editionId: string; bracketId?: string }) {
  const router = useRouter();
  const bracket = data.brackets.find((candidate) => candidate.id === bracketId);
  if (!data.can_manage) return null;
  const mayReseed = bracket && ["draft", "seeded"].includes(bracket.status);

  return <section className="admin-section">
    <h2>Tournament management</h2>
    {!bracket && <TournamentActionForm label="Create single-elimination bracket" onSaved={(id) => router.push(`/app/tournaments?edition=${editionId}&bracket=${id}`)} build={(form) => ({ action: "bracket.create", input: { edition_id: editionId, name: read(form, "name"), bracket_size: Number(read(form, "size")), include_third_place: form.has("third"), rest_policy: read(form, "rest-policy"), minimum_rest_minutes: Number(read(form, "rest-minutes")) } })}>
      <label className="form-field"><span>Bracket name</span><input name="name" maxLength={200} required /></label>
      <label className="form-field"><span>Bracket size</span><select name="size">{[2, 4, 8, 16, 32, 64].map((size) => <option key={size}>{size}</option>)}</select></label>
      <label><input name="third" type="checkbox" /> Include a third-place match</label>
      <label className="form-field"><span>Minimum-rest policy</span><select name="rest-policy"><option value="disabled">Disabled</option><option value="warn">Warn</option><option value="block">Block</option></select></label>
      <label className="form-field"><span>Minimum rest in minutes (0 when disabled)</span><input name="rest-minutes" type="number" min="0" max="1440" defaultValue="0" required /></label>
    </TournamentActionForm>}

    {mayReseed && <details open={bracket.current_revision === 0}>
      <summary>{bracket.current_revision === 0 ? "Accept manual seed snapshot" : "Create a reviewed seed revision"}</summary>
      <p>Seed entries are versioned. A bye is an empty bracket position and creates no Game Center game or score. Reseeding is rejected after play begins.</p>
      <TournamentActionForm label={bracket.current_revision === 0 ? "Accept seeds and generate bracket" : "Accept revised seeds"} build={(form) => {
        const selected = Array.from({ length: bracket.bracket_size }, (_, index) => read(form, `seed-${index + 1}`));
        const seeds = selected.map((entry_id, index) => ({ seed: index + 1, entry_id })).filter((seed) => seed.entry_id);
        if (new Set(seeds.map((seed) => seed.entry_id)).size !== seeds.length) return null;
        return { action: "bracket.seed", input: { edition_id: editionId, bracket_id: bracket.id, expected_version: bracket.version, source_kind: "manual", seeds, reason: read(form, "reason") } };
      }}>
        {Array.from({ length: bracket.bracket_size }, (_, index) => <label className="form-field" key={index}><span>Seed {index + 1}</span><select name={`seed-${index + 1}`} required={index < bracket.bracket_size / 2 + 1}><option value="">Bye / unfilled position</option>{data.entries.map((entry) => <option key={entry.id} value={entry.id}>{entry.name}</option>)}</select></label>)}
        <label className="form-field"><span>Acceptance or override reason</span><textarea name="reason" maxLength={500} required /></label>
      </TournamentActionForm>
    </details>}

    {mayReseed && data.standings_sources.length > 0 && <details>
      <summary>Seed from a published standings snapshot</summary>
      <p>The accepted generation is preserved even when standings are rebuilt later. Tied ranks are rejected until an authorized resolver records a unique order.</p>
      <TournamentActionForm label="Accept standings snapshot" build={(form) => ({ action: "bracket.seed", input: { edition_id: editionId, bracket_id: bracket.id, expected_version: bracket.version, source_kind: "standings_snapshot", source_scope_id: read(form, "scope"), reason: read(form, "reason") } })}>
        <label className="form-field"><span>Standings source</span><select name="scope" required><option value="">Choose published standings</option>{data.standings_sources.map((source) => <option key={source.id} value={source.id}>{source.label} · generation {source.generation} · {source.entry_count} entries</option>)}</select></label>
        <label className="form-field"><span>Acceptance reason</span><textarea name="reason" maxLength={500} required /></label>
      </TournamentActionForm>
    </details>}

    {bracket && data.matches.filter((match) => match.status === "ready" && !match.game_id).map((match) => <details key={match.id}><summary>Schedule {match.label}: {match.primary_name} vs {match.opponent_name}</summary><p>Create the Calendar event and canonical Game Center game first so venue and resource conflict checks remain authoritative, then link the candidate here.</p><TournamentActionForm label="Link canonical game" build={(form) => ({ action: "match.link_game", input: { edition_id: editionId, match_id: match.id, expected_version: match.version, game_id: read(form, "game") } })}><label className="form-field"><span>Game Center candidate</span><select name="game" required><option value="">Choose canonical game</option>{data.games.map((game) => <option value={game.id} key={game.id}>{game.label}</option>)}</select></label></TournamentActionForm></details>)}

    {bracket && data.matches.filter((match) => match.game_status === "final" && match.finalization_count === null).map((match) => <TournamentActionForm key={match.id} label={`Advance official result: ${match.label}`} build={(form) => ({ action: "result.process", input: { edition_id: editionId, match_id: match.id, expected_version: match.version, reason: read(form, "reason") } })}><label className="form-field"><span>Advancement reason</span><textarea name="reason" maxLength={500} required /></label></TournamentActionForm>)}

    {bracket && data.can_policy_manage && data.matches.filter((match) => match.primary_entry_id && match.opponent_entry_id && match.status !== "final").map((match) => <details key={`ruling-${match.id}`}><summary>Administrative ruling: {match.label}</summary><TournamentActionForm label="Record explicit ruling" build={(form) => ({ action: "ruling.create", input: { edition_id: editionId, match_id: match.id, expected_version: match.version, kind: read(form, "kind"), winner_entry_id: read(form, "winner"), loser_entry_id: read(form, "loser"), reason: read(form, "reason") } })}><label className="form-field"><span>Ruling</span><select name="kind"><option value="forfeit">Forfeit</option><option value="withdrawal">Withdrawal</option><option value="disqualification">Disqualification</option><option value="manual_advance">Manual advance</option><option value="correction_resolution">Correction resolution</option></select></label><label className="form-field"><span>Advance</span><select name="winner"><option value={match.primary_entry_id!}>{match.primary_name}</option><option value={match.opponent_entry_id!}>{match.opponent_name}</option></select></label><label className="form-field"><span>Other entry</span><select name="loser"><option value={match.opponent_entry_id!}>{match.opponent_name}</option><option value={match.primary_entry_id!}>{match.primary_name}</option></select></label><label className="form-field"><span>Reason</span><textarea name="reason" maxLength={500} required /></label></TournamentActionForm></details>)}

    {bracket && <details><summary>Bracket controls</summary><TournamentActionForm label="Rebuild current projection" build={() => ({ action: "projection.rebuild", input: { edition_id: editionId, bracket_id: bracket.id, expected_version: bracket.version } })} /><TournamentActionForm label="Archive bracket" build={(form) => form.has("confirm") ? { action: "bracket.archive", input: { edition_id: editionId, bracket_id: bracket.id, expected_version: bracket.version } } : null}><label><input type="checkbox" name="confirm" required /> Archive this bracket while preserving its audit history.</label></TournamentActionForm></details>}
  </section>;
}
