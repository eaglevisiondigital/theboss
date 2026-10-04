"use client";

import { useId, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import type { AdminCommand, AdminField } from "./types";

type FormSection = { title?: string; fields: AdminField[] };

export function MutationForm({
  title,
  description,
  fields = [],
  sections,
  operation,
  initialInput = {},
  buttonLabel = "Save changes",
  buildCommands,
  onSuccess,
}: {
  title: string;
  description?: string;
  fields?: AdminField[];
  sections?: FormSection[];
  operation?: string;
  initialInput?: Record<string, unknown>;
  buttonLabel?: string;
  buildCommands?: (values: Record<string, unknown>) => AdminCommand[];
  onSuccess?: () => void;
}) {
  const formId = useId();
  const router = useRouter();
  const request = useRef<{ fingerprint: string; id: string } | null>(null);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<{ text: string; error: boolean } | null>(null);
  const formSections = sections ?? [{ fields }];

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const form = event.currentTarget;
    const formData = new FormData(form);
    const values: Record<string, unknown> = { ...initialInput };
    for (const field of formSections.flatMap((section) => section.fields)) {
      const raw = formData.get(field.name);
      if (field.type === "checkbox") values[field.name] = raw === "on";
      else if (typeof raw === "string" && raw.trim()) {
        values[field.name] = field.type === "number"
          ? Number(raw)
          : field.type === "datetime-local" ? new Date(raw).toISOString() : raw.trim();
      } else if (field.value != null && field.value !== "") {
        values[field.name] = null;
      }
    }
    const commands = buildCommands ? buildCommands(values) : [{ operation: operation ?? "", input: values }];
    const fingerprint = JSON.stringify(commands);
    if (request.current?.fingerprint !== fingerprint) request.current = { fingerprint, id: crypto.randomUUID() };
    setPending(true);
    setNotice(null);
    try {
      const response = await fetch("/app/admin/mutate", {
        method: "POST",
        credentials: "same-origin",
        cache: "no-store",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ commands, request_id: request.current.id }),
      });
      const result: unknown = await response.json();
      if (!response.ok || typeof result !== "object" || result === null || !("ok" in result) || result.ok !== true) {
        setNotice({ text: "We could not save this change. Check your access and the entered fields, then try again.", error: true });
        return;
      }
      request.current = null;
      setNotice({ text: "Saved. Your records have been refreshed.", error: false });
      onSuccess?.();
      router.refresh();
    } catch {
      setNotice({ text: "We could not confirm the change. Try again with the same fields to safely retry.", error: true });
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="admin-form" onSubmit={submit} aria-labelledby={`${formId}-title`}>
      <div className="admin-form-heading">
        <h3 id={`${formId}-title`}>{title}</h3>
        {description && <p>{description}</p>}
      </div>
      {formSections.map((section, sectionIndex) => (
        <fieldset key={sectionIndex} className="admin-fieldset" disabled={pending}>
          {section.title && <legend>{section.title}</legend>}
          <div className="admin-fields">
            {section.fields.map((field) => {
              const id = `${formId}-${field.name}`;
              const hintId = field.hint ? `${id}-hint` : undefined;
              return (
                <div className={`form-field ${field.type === "checkbox" ? "checkbox-field" : ""}`} key={field.name}>
                  {field.type === "checkbox" ? (
                    <label htmlFor={id}><input id={id} type="checkbox" name={field.name} defaultChecked={field.value === true} aria-describedby={hintId} />{field.label}</label>
                  ) : (
                    <>
                      <label htmlFor={id}>{field.label}{field.required && <span aria-hidden="true"> *</span>}</label>
                      {field.type === "select" ? (
                        <select id={id} name={field.name} required={field.required} defaultValue={String(field.value ?? "")} aria-describedby={hintId} onChange={field.onValueChange ? (event) => field.onValueChange?.(event.currentTarget.value) : undefined}>
                          <option value="">{field.required ? "Choose a record" : "None"}</option>
                          {field.options?.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
                        </select>
                      ) : (
                        <input id={id} name={field.name} type={field.type ?? "text"} required={field.required} defaultValue={String(field.value ?? "")} maxLength={field.maxLength ?? 120} placeholder={field.placeholder} aria-describedby={hintId} autoComplete="off" />
                      )}
                    </>
                  )}
                  {field.hint && <p className="field-hint" id={hintId}>{field.hint}</p>}
                </div>
              );
            })}
          </div>
        </fieldset>
      ))}
      <div className="admin-form-footer">
        <button className="button button-primary" type="submit" disabled={pending}>{pending ? "Saving..." : buttonLabel}</button>
        {notice && <p className={`save-notice ${notice.error ? "save-error" : ""}`} role={notice.error ? "alert" : "status"}>{notice.text}</p>}
      </div>
    </form>
  );
}
