"use client";
import { useState } from "react";
import { GameForm } from "@/components/games/action-form";
import type { GameData } from "@/lib/games/contracts";
import { fieldText } from "../coordination/action-form";
import { statCatalog } from "@/lib/stat-tracking/catalog";
import { trackingPresets } from "@/lib/stat-tracking/profile";
export function TrackingManagement({ data }: { data: GameData }) {
  const choices = data.tracking_management ?? [], [selected, setSelected] = useState(0);
  const context = choices[selected];
  if (!context || data.view === "family") return null;
  const optional = statCatalog.volleyball.filter(s => s.available && s.classification === "optional");
  return <details className="game-management-panel"><summary>Volleyball tracking defaults</summary><p>Choose the exact context. Filter games by team or program to manage those defaults. Changes apply when a new game snapshot is created. Existing games keep their own snapshots.</p><label className="form-field"><span>Management context</span><select value={selected} onChange={e => setSelected(Number(e.target.value))}>{choices.map((c,i) => <option key={i} value={i}>{c.label} / {c.scope_type.replaceAll("_"," ")}</option>)}</select></label><GameForm key={`${selected}:${context.profile_version}`} label="Save tracking default" build={f => {
    const preset = fieldText(f,"preset"), quick=fieldText(f,"quick").split(",").map(s=>s.trim()).filter(Boolean);
    return { operation:"tracking.profile.set",input:{ sport_key:"volleyball",scope_type:context.scope_type,organization_id:context.organization_id,...(context.unit_id?{unit_id:context.unit_id}:{}),...(context.team_id?{team_id:context.team_id}:{}),...(context.season_id?{season_id:context.season_id}:{}),expected_profile_version:context.profile_version,preset,...(preset==="custom"?{enabled:optional.filter(s=>f.get(s.key)==="on").map(s=>s.key),quick}:{}),status:fieldText(f,"status"),reason:fieldText(f,"reason") } };
  }}><label className="form-field"><span>Preset</span><select name="preset" defaultValue={context.selection.preset}>{trackingPresets.map(p=><option key={p} value={p}>{p.replaceAll("_"," ")}</option>)}</select></label><details><summary>Custom statistics and Quick Stats</summary>{optional.map(s=><label className="game-confirmation" key={s.key}><input type="checkbox" name={s.key} defaultChecked={context.selection.enabled.includes(s.key)}/>{s.short_label}</label>)}<label className="form-field"><span>Ordered Quick Stat keys, separated by commas (maximum eight)</span><input name="quick" maxLength={600} defaultValue={context.selection.quick.join(", ")}/></label></details><label className="form-field"><span>Status</span><select name="status" defaultValue={context.status}><option value="active">Active</option><option value="inactive">Inactive / inherit</option></select></label><label className="form-field"><span>Reason</span><input name="reason" required maxLength={500}/></label></GameForm></details>;
}
