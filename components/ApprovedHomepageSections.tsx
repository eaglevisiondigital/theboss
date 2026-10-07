import BossPlusIcon from "./BossPlusIcon";
import Link from "next/link";
import ReferencePhoto from "./ReferencePhoto";
import s from "@/app/approvedSections.module.css";
import f from "@/app/homeFeatures.module.css";

function CostIcon({ kind }: { kind: string }) {
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

const costs = [
  { label: "Sports fees", kind: "sports" }, { label: "Team gear", kind: "gear" },
  { label: "Camps", kind: "camps" }, { label: "Travel", kind: "travel" },
];

export default function ApprovedHomepageSections() {
  return <>
    <section className={f.savings} aria-labelledby="savings-title"><div className={f.savingsCanvas}>
      <ReferencePhoto crop="542 578 251 255" preserveAspectRatio="xMidYMin slice" alt="A young woman showing a Boss Bucks discount on her phone" className={f.savingsPortrait}/>
      <figure className={f.discountPhone}>
        <svg viewBox="205 14 686 1366" role="img" aria-label="Approved Boss Bucks Discounts app preview"><defs><clipPath id="home-discounts-phone"><rect x="205" y="14" width="686" height="1366" rx="120"/></clipPath></defs><image href="/images/approved/discounts-original.png" width="1122" height="1402" clipPath="url(#home-discounts-phone)"/></svg>
        <figcaption>Illustrative product preview</figcaption>
      </figure>
      <div className={f.savingsCopy}>
        <h2 id="savings-title">Save<br/>Like a <span>Boss.</span></h2>
        <p>Discover participating local deals, support your community and make everyday spending go further.</p>
        <Link className={f.button} href="/boss-bucks">Explore Boss Bucks</Link>
      </div></div>
    </section>

    <section className={f.money} aria-labelledby="money-title"><div className={f.moneyCanvas}>
      <ReferencePhoto source="/images/approved/home-football-plain-helmets.webp" crop="284 891 285 347" alt="Young athletes celebrating with their team" className={f.moneyPhoto} preserveAspectRatio="xMidYMid slice"/>
      <div className={f.moneyCopy}>
        <h2 id="money-title">The Digital<br/><span>Money Board</span></h2>
        <h3>Fundraise Like a Boss.</h3>
        <p>Choose an amount or take a spin. Watch the board fill as supporters help your team reach its goal.</p>
        <ul className={f.checks}><li>Donate or Spin</li><li>Visible progress</li><li>Team and participant credit</li></ul>
        <Link className={f.button} href="/money-board">Explore the Money Board</Link>
      </div>
      <figure className={f.moneyPhone}>
        <svg viewBox="0 0 751 1492" width="751" height="1492" role="img" aria-label="Approved Digital Money Board app preview"><defs><clipPath id="home-money-phone-outline"><rect x="16" y="8" width="720" height="1474" rx="130"/><rect x="9" y="229" width="9" height="51" rx="3"/><rect x="9" y="340" width="9" height="92" rx="3"/><rect x="9" y="464" width="9" height="91" rx="3"/><rect x="734" y="382" width="8" height="165" rx="3"/></clipPath></defs><image href="/images/approved/money-board-original.png" width="751" height="1492" clipPath="url(#home-money-phone-outline)"/></svg>
        <figcaption>Illustrative product preview</figcaption>
      </figure></div>
    </section>

    <section className={f.family} aria-labelledby="family-title">
      <div className={f.familyMain}>
        <img src="/images/approved/boss-bucks-hero.png" width="2172" height="724" alt="Parents celebrating with their young athlete" className={f.familyPhoto}/>
        <div className={f.familyCopy}>
          <h2 id="family-title">Help cover<br/><span>approved costs.</span></h2>
          <p>Raise or earn Boss Bucks through approved campaigns. Apply your balance toward sports fees, registration, team gear, children’s and youth camps, tournaments and eligible travel expenses.</p>
          <Link className={f.button} href="/boss-bucks">See how Boss Bucks work</Link>
        </div>
        <div className={f.walletPreview} aria-label="Family Boss Bucks approved spending categories">
          <div className={f.walletHeading}><span className={f.walletIcon}><CostIcon kind="wallet"/></span><div><h3>Family Boss Bucks</h3><p><span aria-hidden="true">✓</span> Approved costs</p></div></div>
          <div className={f.costs}>{costs.map(cost => <div key={cost.kind}><CostIcon kind={cost.kind}/><span>{cost.label}</span></div>)}</div>
        </div>
      </div>
      <div className={f.giftCards}>
        <span className={f.giftIcons}><CostIcon kind="gas"/><CostIcon kind="meal"/></span>
        <strong>Coming soon</strong><p>Use Boss Bucks to purchase gas and restaurant gift cards.</p>
      </div>
      <p className={f.integrity}>Family and participant Boss Bucks stay within approved spending options, with no cash withdrawals or personal bank transfers. Only eligible team and organization proceeds can transfer to their approved bank accounts.</p>
    </section>

    <section className={s.engage} aria-labelledby="engage-title">
      <ReferencePhoto source="/images/approved/home-photos-single-b.webp" crop="618 1532 175 145" alt="A parent and child staying connected with their team" className={s.engagePhoto}/>
      <div className={s.engageCopy}>
        <h2 id="engage-title">Engage Like a <span>Boss.</span></h2>
        <h3>Keep teams organized and families connected.</h3>
        <p>Registration, rosters, schedules, communication and team stores.</p>
        <Link className={s.button} href="/engage">Explore Boss Engage</Link>
      </div>
      <figure className={s.schedulePreview}>
        <div className={s.scheduleCard}>
          <div className={s.scheduleTabs}><span>Schedule</span><span>Messages</span><span>Family Hub</span></div>
          <div className={s.scheduleRow}><span>Sat, Apr 12</span><span>Away Game</span><span>10:00 AM</span><span aria-hidden="true">›</span></div>
          <div className={s.scheduleRow}><span>Tue, Apr 15</span><span>Practice</span><span>5:30 PM</span><span aria-hidden="true">›</span></div>
          <div className={s.scheduleRow}><span>Sat, Apr 19</span><span>Home Game</span><span>11:00 AM</span><span aria-hidden="true">›</span></div>
        </div>
        <figcaption>Platform vision</figcaption>
      </figure>
    </section>

    <section className={s.merchant} aria-labelledby="merchant-title">
      <ReferencePhoto crop="0 1680 285 96" alt="A local business owner welcoming the community" className={s.merchantPhoto}/>
      <div className={s.merchantCopy}><h2 id="merchant-title"><span>Partner with</span> The Boss</h2><p>Connect with families. Offer useful savings.<br/>Support your community.</p></div>
      <Link className={s.button} href="/merchant-partner">Become a Merchant</Link>
    </section>

    <section className={s.finalCta} aria-labelledby="start-title">
      <h2 id="start-title">Fundraise <span>Like a Boss.</span></h2>
      <p>Tell us about your team or organization. Find the right Boss starting point.</p>
      <Link className={s.button} href="/fundraising/get-started">Get Started</Link>
    </section>

    <footer className={s.footer} role="contentinfo">
      <div className={s.footerIdentity}><Link href="/" className={s.footerBrand} aria-label="The Boss home"><BossPlusIcon/><span>THE BOSS</span></Link><p>People. Purpose. Possibilities.</p></div>
      <nav aria-label="Footer navigation"><Link href="/fundraising">Fundraise</Link><Link href="/boss-bucks">Save</Link><Link href="/engage">Engage</Link><Link href="/organizations">Organizations</Link><Link href="/family-hub">Families</Link><Link href="/merchants">Merchants</Link><Link href="/contact">Contact</Link></nav>
      <div className={s.footerBottom}><span>© 2026 The Boss. All rights reserved.</span><div><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></div></div>
    </footer>
  </>;
}
