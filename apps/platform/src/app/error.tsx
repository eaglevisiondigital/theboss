"use client";

import Link from "next/link";
import { useEffect } from "react";
import { merchantClientDiagnostic } from "@/lib/merchants/diagnostics-client";

export default function ErrorPage({ error, retry }: { error: Error & {digest?:string}; retry: () => void }) {
  useEffect(()=>{merchantClientDiagnostic({stage:"error_boundary",observedAt:"src/app/error.tsx",classification:"exception",error});},[error]);
  return (
    <main id="main-content" className="recovery-main container">
      <p className="eyebrow muted">The Boss</p>
      <h1>We couldn’t load this page.</h1>
      <p>Please try again in a moment.</p>
      <div className="recovery-actions">
        <button className="button button-primary" type="button" onClick={()=>{merchantClientDiagnostic({stage:"retry_requested",observedAt:"src/app/error.tsx"});retry();}}>Try again</button>
        <Link className="button button-outline" href="/">Go to home</Link>
      </div>
    </main>
  );
}
