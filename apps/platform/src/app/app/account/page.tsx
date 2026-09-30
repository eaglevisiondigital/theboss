import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";

export const metadata: Metadata = { title: "Account" };

export default async function AccountPage() {
  await requireSession("/app/account");

  return (
    <>
      <div className="page-heading">
        <p className="eyebrow muted">Account</p>
        <h1>Your Boss account.</h1>
        <p>One account for your place in the Boss ecosystem.</p>
      </div>
      <section className="account-panel" aria-labelledby="session-title">
        <div className="account-panel-heading">
          <span className="session-indicator" aria-hidden="true" />
          <div>
            <h2 id="session-title">Your session</h2>
            <p>You’re signed in on this browser.</p>
          </div>
        </div>
        <div className="account-panel-action">
          <p>Sign out when you’re finished, especially on a shared device.</p>
          <form action="/auth/logout" method="post">
            <button className="button button-outline" type="submit">Sign out</button>
          </form>
        </div>
      </section>
    </>
  );
}
