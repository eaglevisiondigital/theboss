"use client";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import ReferencePhoto from "./ReferencePhoto";
import s from "@/app/approvedHome.module.css";
const links = [["Fundraise", "/fundraising"], ["Save", "/boss-bucks"], ["Engage", "/engage"], ["Who It’s For", "/organizations"], ["The Vision", "/about"]];
export default function ApprovedHeader() {
  const [open, setOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const buttonRef = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (!open) return;
    const dismiss = (event: PointerEvent) => { if (!menuRef.current?.contains(event.target as Node)) setOpen(false); };
    const escape = (event: KeyboardEvent) => { if (event.key === "Escape") { setOpen(false); buttonRef.current?.focus(); } };
    document.addEventListener("pointerdown", dismiss);
    document.addEventListener("keydown", escape);
    return () => { document.removeEventListener("pointerdown", dismiss); document.removeEventListener("keydown", escape); };
  }, [open]);
  return <header className={s.header}>
    <Link href="/" className={s.brand} aria-label="The Boss home"><ReferencePhoto crop="37 5 39 38" className={s.brandMark}/><span>THE BOSS</span></Link>
    <nav className={s.desktopNav} aria-label="Primary navigation">{links.map(([label, href]) => <Link href={href} key={href}>{label}</Link>)}</nav>
    <Link href="/fundraising/get-started" className={s.headerCta}>Get Started <span aria-hidden="true">›</span></Link>
    <div className={s.mobileMenu} ref={menuRef}>
      <button ref={buttonRef} type="button" onClick={() => setOpen(!open)} aria-expanded={open} aria-controls="mobile-navigation" aria-label={open ? "Close navigation" : "Open navigation"} className={s.menuButton}><span/><span/><span/></button>
      <nav id="mobile-navigation" className={s.mobilePanel} aria-label="Mobile navigation" hidden={!open}>{links.map(([label, href]) => <Link href={href} key={href} onClick={() => setOpen(false)}>{label}</Link>)}</nav>
    </div>
  </header>;
}
