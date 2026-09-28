import Link from "next/link";
import styles from "./siteChrome.module.css";

export default function SiteFooter(){
  return <footer className={styles.footer}>
    <div className={styles.footerTop}>
      <div>
        <div className={styles.footerBrand}>BOSS <span>PLUS</span></div>
        <p>People. Purpose. Possibilities.</p>
      </div>
      <div className={styles.footerGrid}>
        <div><b>Raise</b><Link href="/fundraising">Boss Fundraising</Link><Link href="/money-board">Money Board</Link><Link href="/fundraising/get-started">Start a Fundraiser</Link></div>
        <div><b>Save & Engage</b><Link href="/boss-bucks">Boss Bucks</Link><Link href="/engage">Boss Engage</Link><Link href="/family-hub">Family Hub</Link></div>
        <div><b>Who We Serve</b><Link href="/sports-teams">Sports Teams</Link><Link href="/organizations">Organizations</Link><Link href="/merchants">Merchants</Link></div>
        <div><b>Company</b><Link href="/about">The Boss Ecosystem</Link><Link href="/how-it-works">How It Works</Link><Link href="/contact">Contact</Link></div>
      </div>
    </div>
    <div className={styles.footerBottom}>
      <span>© 2026 BOSS PLUS. All rights reserved.</span>
      <div><Link href="/privacy">Privacy</Link><Link href="/terms">Terms</Link></div>
    </div>
  </footer>
}
