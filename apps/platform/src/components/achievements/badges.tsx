import Link from "next/link";
import type { Json } from "@/lib/supabase/database.types";
export function AchievementBadges({ items }: { items: Record<string, Json>[] }) {
  const text = (v: Json | undefined) => typeof v === "string" ? v : "";
  return <div className="achievement-badge-grid">{items.map((item, index) => <article className="achievement-badge" key={text(item.id) || index}>
    <span className="achievement-symbol" aria-hidden="true">{item.badge_icon === "record" ? "★" : "◆"}</span>
    <h3>{text(item.name) || text(item.title)}</h3><p>{(text(item.category) || text(item.achievement_type) || text(item.type)).replaceAll("_", " ")}{item.sport_key ? ` · ${text(item.sport_key)}` : ""}</p>
    <p><strong>{text(item.verification_level) === "boss_verified" ? "Boss verified" : text(item.verification_level) === "organization_verified" ? "Organization verified" : "Self entered"}</strong></p>
    <p>{item.co_holder === true ? "Co-Record Holder" : item.current_holder === true ? "Current Record Holder" : text(item.state) === "historical" ? "Historical recognition" : text(item.state) === "processing" ? "Processing source update" : text(item.state) === "corrected" ? "Corrected by authoritative source" : text(item.state) === "revoked" ? "Revoked organization award" : text(item.state) === "unavailable" ? "Source currently unavailable" : "Verified recognition"}{item.tier ? ` · ${text(item.tier)}` : ""}</p>
    <small>{text(item.achieved_on) || text(item.achieved_at).slice(0, 10) || "Date not recorded"}</small>
    {typeof item.id === "string" && item.source_type && <Link href={`/app/achievements?recognition=${item.id}`}>Recognition history</Link>}
  </article>)}</div>;
}
