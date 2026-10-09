export default function CostIcon({ kind }: { kind: string }) {
  return <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {kind === "sports" ? <><circle cx="16" cy="16" r="12"/><path d="m16 9 6 4-2 7h-8l-2-7 6-4ZM16 9V4M22 13l5-2M20 20l3 6M12 20l-3 6M10 13l-5-2"/></> :
      kind === "gear" ? <path fill="currentColor" stroke="none" d="m10 4-8 5 4 7 4-2v14h12V14l4 2 4-7-8-5c-1 4-11 4-12 0Z"/> :
      kind === "camps" ? <><path fill="currentColor" stroke="none" d="M16 3 1 28h30L16 3Z"/><path stroke="white" d="M16 9v18m0-10-6 10m6-10 6 10"/></> :
      kind === "travel" ? <path fill="currentColor" stroke="none" d="m30 5-2-2-10 9-11-3-3 3 9 5-6 6-4-1-2 2 6 2 2 6 2-2-1-4 6-6 5 9 3-3-3-11 8-10Z"/> :
      kind === "gas" ? <><path d="M4 29h16M6 29V4h12v25M8 7h8v8H8ZM18 18h4v7c0 4 5 4 5 0V12l-5-6m2 2v6h3"/></> :
      kind === "meal" ? <><path d="M7 3v10m-4-10v6c0 5 8 5 8 0V3M7 13v16M24 3v26M24 3c-7 0-7 16 0 16"/></> :
      <><rect x="3" y="8" width="26" height="21" rx="4"/><path d="M26 8V4H7a4 4 0 0 0-4 4m26 10H19v6h10"/><circle cx="23" cy="21" r=".5"/></>}
  </svg>;
}

