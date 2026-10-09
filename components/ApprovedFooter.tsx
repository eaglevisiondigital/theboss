import BossPlusIcon from "./BossPlusIcon";
import Link from "next/link";
import s from "./approvedFooter.module.css";

const groups = [
  { title: "Fundraise & save", links: [["Boss Fundraising", "/fundraising"], ["Digital Money Board", "/money-board"], ["Boss Bucks Discounts", "/boss-bucks"], ["Boss Bucks Account", "/boss-bucks-account"]] },
  { title: "Stay connected", links: [["Boss Engage", "/engage"], ["Family Hub", "/family-hub"], ["Who It’s For", "/organizations"], ["For Merchants", "/merchants"]] },
  { title: "Explore The Boss", links: [["Our Vision", "/about"], ["How It Works", "/how-it-works"], ["Request Information", "/request-information"], ["Contact Us", "/contact"]] },
];

export default function ApprovedFooter({ showInformationCTA = true, polished = false }: { showInformationCTA?: boolean; polished?: boolean }) {
  return <footer className={`${s.footer} ${polished ? s.polished : ""}`}>
    {showInformationCTA && <div className={s.information}>
      <div className={s.informationInner}>
        <div><p className={s.eyebrow}>YOUR NEXT STEP STARTS HERE</p><h2>{polished ? "Let’s Find Your " : "Let’s find your "}<span>{polished ? "Next Step." : "next step."}</span></h2><p>Have questions? Choose what you’d like to learn about, and our team will help you explore the possibilities.</p></div>
        <Link className={s.informationButton} href="/request-information">Request Information <span aria-hidden="true">↗</span></Link>
      </div>
    </div>}
    <div className={s.inner}>
      <div className={s.top}>
        <div className={s.identity}>
          <Link href="/" className={s.brand} aria-label="The Boss home"><BossPlusIcon /><span>THE BOSS</span></Link>
          <p className={s.tagline}>People. Purpose. Possibilities.</p>
          <p>Tools to help communities fundraise, save and stay connected.</p>
          <Link className={s.startLink} href="/fundraising/get-started">Start a Fundraiser <span aria-hidden="true">→</span></Link>
        </div>
        <nav className={s.navigation} aria-label="Footer navigation">
          {groups.map(group => <div key={group.title}><h2>{polished ? ({"Fundraise & save":"Fundraise & Save","Stay connected":"Stay Connected"}[group.title] || group.title) : group.title}</h2><ul>{group.links.map(([label, href]) => <li key={href}><Link href={href}>{label}</Link></li>)}</ul></div>)}
        </nav>
      </div>
      <div className={s.bottom}><span>© 2026 The Boss. All rights reserved.</span><div><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></div></div>
    </div>
  </footer>;
}
