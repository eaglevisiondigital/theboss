"use client";

import { FormEvent, ReactNode, useState } from "react";
import { useRouter } from "next/navigation";

export default function NetlifyForm({
  name,
  children,
  className
}: {
  name: string;
  children: ReactNode;
  className?: string;
}) {
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;
    const form = event.currentTarget;
    setSubmitting(true);
    setError("");

    const formData = new FormData(form);
    const body = new URLSearchParams();

    formData.forEach((value, key) => {
      body.append(key, String(value));
    });

    try {
      const response = await fetch("/__forms.html", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: body.toString()
      });

      if (!response.ok) throw new Error("Submission failed");

      form.reset();
      router.push("/thanks");
    } catch {
      setError("We could not submit the form. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form name={name} className={className} onSubmit={handleSubmit}>
      <input type="hidden" name="form-name" value={name} />
      {children}
      {error ? <p role="alert">{error}</p> : null}
      {submitting ? <p aria-live="polite">Sending...</p> : null}
    </form>
  );
}
