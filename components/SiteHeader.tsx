import Link from "next/link";
import styles from "./siteChrome.module.css";

export default function SiteHeader(){
  return <header className={styles.header}>
    <Link className={styles.brand} href="/" aria-label="BOSS PLUS home">
      <span>BOSS</span><strong>PLUS</strong>
    </Link>
    <nav className={styles.nav} aria-label="Primary navigation">
      <Link href="/fundraising">Fundraising</Link>
      <Link href="/boss-bucks">Boss Bucks</Link>
      <Link href="/engage">Engage</Link>
      <Link href="/sports-teams">Sports Teams</Link>
      <Link href="/organizations">Organizations</Link>
      <Link href="/merchants">Merchants</Link>
    </nav>
    <div className={styles.actions}>
      <Link className={styles.login} href="/contact">Contact</Link>
      <Link className={styles.cta} href="/get-started">Get Started</Link>
    </div>
  </header>
}
