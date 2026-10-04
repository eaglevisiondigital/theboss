import BossPlusIcon from "./BossPlusIcon";
import Link from "next/link";
import s from "@/app/approvedSections.module.css";
export default function ApprovedFooter(){return (    <footer className={s.footer} role="contentinfo">
      <div className={s.footerIdentity}><Link href="/" className={s.footerBrand} aria-label="The Boss home"><BossPlusIcon/><span>THE BOSS</span></Link><p>People. Purpose. Possibilities.</p></div>
      <nav aria-label="Footer navigation"><Link href="/fundraising">Fundraise</Link><Link href="/boss-bucks">Save</Link><Link href="/engage">Engage</Link><Link href="/organizations">Organizations</Link><Link href="/family-hub">Families</Link><Link href="/boss-bucks-account">Boss Bucks Account</Link><Link href="/merchants">Merchants</Link><Link href="/request-information">Request Information</Link><Link href="/contact">Contact</Link></nav>
      <div className={s.footerBottom}><span>© 2026 The Boss. All rights reserved.</span><div><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></div></div>
    </footer>);}
