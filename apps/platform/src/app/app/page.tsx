import type { Metadata } from "next";
import Link from "next/link";
import { requireSession } from "@/lib/auth/session";

export const metadata: Metadata = { title: "Home" };

export default async function AppHomePage() {
  await requireSession();

  return (
    <>
      <div className="page-heading">
        <p className="eyebrow muted">Home</p>
        <h1>Welcome to The Boss.</h1>
        <p>Your account is the starting point for your Boss connections.</p>
      </div>
      <section className="welcome-panel" aria-labelledby="welcome-title">
        <div>
          <p className="eyebrow"><span className="eyebrow-mark" aria-hidden="true" />Your Boss account</p>
          <h2 id="welcome-title">You’re signed in.</h2>
          <p>This space will grow with you as The Boss platform takes shape.</p>
          <Link className="button button-primary" href="/app/account">
            View your account
            <span aria-hidden="true">↗</span>
          </Link>
        </div>
        <span className="welcome-word" aria-hidden="true">BOSS.</span>
      </section>
    </>
  );
}
