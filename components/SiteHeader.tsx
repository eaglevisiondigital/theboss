import Link from "next/link";
import styles from "./siteChrome.module.css";

const menu = [
  ["Fundraising","/fundraising"],
  ["Boss Bucks","/boss-bucks"],
  ["Money Board","/money-board"],
  ["Boss Engage","/engage"],
  ["Family Hub","/family-hub"],
  ["Sports Teams","/sports-teams"],
  ["Organizations","/organizations"],
  ["Merchants","/merchants"]
];

export default function SiteHeader(){
  return <header className={styles.header}>
    <Link className={styles.brand} href="/" aria-label="BOSS PLUS home">
      <span className={styles.brandWords}><span>BOSS</span><strong>PLUS</strong></span>
      <small>THE BOSS ECOSYSTEM</small>
    </Link>

    <nav className={styles.nav} aria-label="Primary navigation">
      <Link href="/fundraising">Fundraising</Link>
      <Link href="/boss-bucks">Boss Bucks</Link>
      <Link href="/money-board">Money Board</Link>
      <Link href="/engage">Engage</Link>
      <Link href="/sports-teams">Sports Teams</Link>
      <Link href="/organizations">Organizations</Link>
      <Link href="/merchants">Merchants</Link>
    </nav>

    <div className={styles.actions}>
      <Link className={styles.login} href="/contact">Contact</Link>
      <Link className={styles.cta} href="/get-started">Get Started <span>→</span></Link>
    </div>

    <details className={styles.mobileMenu}>
      <summary aria-label="Open menu"><span></span><span></span><span></span></summary>
      <div className={styles.mobilePanel}>
        {menu.map(([label,href]) => <Link key={href} href={href}>{label}</Link>)}
        <Link href="/how-it-works">How It Works</Link>
        <Link href="/about">About Boss</Link>
        <Link href="/contact">Contact</Link>
        <Link className={styles.mobileCta} href="/get-started">Get Started</Link>
      </div>
    </details>
  </header>
}
