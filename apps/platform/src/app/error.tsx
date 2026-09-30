"use client";

import Link from "next/link";

export default function ErrorPage({ retry }: { retry: () => void }) {
  return (
    <main id="main-content" className="recovery-main container">
      <p className="eyebrow muted">The Boss</p>
      <h1>We couldn’t load this page.</h1>
      <p>Please try again in a moment.</p>
      <div className="recovery-actions">
        <button className="button button-primary" type="button" onClick={retry}>Try again</button>
        <Link className="button button-outline" href="/">Go to home</Link>
      </div>
    </main>
  );
}
