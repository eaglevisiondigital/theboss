import Link from "next/link";
import type { Choice } from "@/lib/coordination/input";
import { addDays } from "@/lib/calendar/temporal";
export const humanize = (value: string) => value.replaceAll("_", " ").replace(/^./, character => character.toUpperCase());
export function displayInstant(value: string, timezone = "UTC") { return new Intl.DateTimeFormat("en-US", { timeZone: timezone, dateStyle: "medium", timeStyle: "short" }).format(new Date(value)); }
export function coordinationHref(resource: "attendance" | "volunteers", query: object, changes: Record<string, string | undefined> = {}) {
  const names: Record<string, string> = { organization_id: "org", team_id: "team", unit_id: "unit", event_id: "event", shift_id: "shift", child_person_id: "child", occurrence_key: "occurrence", person_id: "person" }, params = new URLSearchParams();
  for (const [key, value] of Object.entries({ ...query, ...changes })) if (typeof value === "string" && value) params.set(names[key] ?? key, value);
  return `/app/${resource}?${params.toString()}`;
}
export function CoordinationFilters({ resource, query, organizations, teams = [], units = [], children = [], events = [] }: { resource: "attendance" | "volunteers"; query: { view: string; from: string; to: string; organization_id?: string; team_id?: string; unit_id?: string; child_person_id?: string; event_id?: string }; organizations: Choice[]; teams?: Choice[]; units?: Choice[]; children?: Choice[]; events?: Choice[] }) {
  return <details className="coordination-filter-panel"><summary>Filter {resource === "attendance" ? "events and children" : "volunteer needs"}</summary><form method="get" className="coordination-filters" action={`/app/${resource}`}><input type="hidden" name="view" value={query.view} />
    {organizations.length > 0 && <label className="form-field"><span>Organization</span><select name="org" defaultValue={query.organization_id ?? ""}><option value="">Default available organization</option>{organizations.map(choice => <option value={choice.id} key={choice.id}>{choice.label}</option>)}</select></label>}
    {teams.length > 0 && <label className="form-field"><span>Team</span><select name="team" defaultValue={query.team_id ?? ""}><option value="">All available teams</option>{teams.map(choice => <option value={choice.id} key={choice.id}>{choice.label}</option>)}</select></label>}
    {units.length > 0 && <label className="form-field"><span>Program / unit</span><select name="unit" defaultValue={query.unit_id ?? ""}><option value="">All available units</option>{units.map(choice => <option value={choice.id} key={choice.id}>{choice.label}</option>)}</select></label>}
    {children.length > 0 && <label className="form-field"><span>Child</span><select name="child" defaultValue={query.child_person_id ?? ""}><option value="">Whole family</option>{children.map(choice => <option value={choice.id} key={choice.id}>{choice.label}</option>)}</select></label>}
    {events.length > 0 && <label className="form-field"><span>Event</span><select name="event" defaultValue={query.event_id ?? ""}><option value="">All available events</option>{events.map(choice => <option value={choice.id} key={choice.id}>{choice.label}</option>)}</select></label>}
    <label className="form-field"><span>From date (UTC)</span><input type="date" name="from" defaultValue={query.from.slice(0, 10)} required /></label><label className="form-field"><span>Through date (UTC)</span><input type="date" name="to" defaultValue={addDays(query.to.slice(0, 10), -1)} required /></label><div className="coordination-filter-actions"><button className="button button-outline button-small" type="submit">Apply filters</button><Link href={`/app/${resource}`} className="button button-outline button-small">Reset</Link></div></form></details>;
}
