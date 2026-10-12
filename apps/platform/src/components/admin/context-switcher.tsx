"use client";

import { useId } from "react";
import { usePathname, useRouter } from "next/navigation";
import type { AdminRecord } from "./types";

export function OrganizationContext({ organizations, selected }: { organizations: AdminRecord[]; selected: string | null }) {
  const id = useId();
  const pathname = usePathname();
  const router = useRouter();
  if (!organizations.length) return null;
  return (
    <div className="organization-context">
      <div><p className="eyebrow muted">Organization context</p><p className="context-caption">Choose where you are working.</p></div>
      <div className="form-field">
        <label className="visually-hidden" htmlFor={id}>Current organization</label>
        <select id={id} value={selected ?? ""} onChange={(event) => {
          const value = event.currentTarget.value;
          if (value && !organizations.some((organization) => organization.id === value)) return;
          const search = new URLSearchParams(window.location.search);
          if (value) search.set("org", value); else search.delete("org");
          search.delete("q");
          router.push(`${pathname}${search.size ? `?${search.toString()}` : ""}`);
        }}>
          <option value="">No organization selected</option>
          {organizations.map((organization) => <option key={organization.id} value={organization.id}>{organization.label}</option>)}
        </select>
      </div>
    </div>
  );
}
