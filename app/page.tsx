import Image from "next/image";
import Link from "next/link";
import ApprovedHeader from "@/components/ApprovedHeader";
import ReferencePhoto from "@/components/ReferencePhoto";
import s from "./approvedHome.module.css";

const pillars = [
  { title: "Fundraise", description: "Cards, donations and the Digital Money Board.", href: "/fundraising", crop: "24 470 243 97", alt: "Football players gathering with their team", icon: "fundraise" },
  { title: "Save", description: "Useful discounts and value toward approved costs.", href: "/boss-bucks", crop: "288 470 236 97", alt: "A woman enjoying a day in her community", icon: "save" },
  { title: "Engage", description: "Teams, schedules and families connected.", href: "/engage", crop: "541 470 231 97", alt: "A coach bringing young athletes together", icon: "engage" },
];
function PillarIcon({ kind }: { kind: string }) {
  return <svg viewBox="0 0 32 32" fill="currentColor" aria-hidden="true">
    {kind === "fundraise" ? <><rect x="5" y="19" width="5" height="10" rx=".7"/><rect x="13" y="12" width="5" height="17" rx=".7"/><rect x="21" y="5" width="5" height="24" rx=".7"/></> :
      kind === "save" ? <path d="M16 28 4.6 16.6C-2.8 8.9 8 0 16 9c8-9 18.8-.1 11.4 7.6Z"/> :
      <><circle cx="16" cy="10" r="5"/><circle cx="6" cy="9" r="3.6"/><circle cx="26" cy="9" r="3.6"/><path d="M8 28v-6c0-5 3-7 8-7s8 2 8 7v6ZM1 24v-6c0-3 2-5 5-5 2 0 3 .8 4 2-3 2-4 4-4 9ZM26 24c0-5-1-7-4-9 1-1.2 2-2 4-2 3 0 5 2 5 5v6Z"/></>}
  </svg>;
}
export default function Home() {
  return <div className={s.home}>
    <a className={s.skipLink} href="#main">Skip to content</a>
    <ApprovedHeader/>
    <main id="main">
      <section className={s.hero} aria-labelledby="hero-title">
        <div className={s.heroPhoto}><Image src="/images/approved/hero-team.png" alt="Young athletes in black and orange uniforms gathering together" fill priority sizes="100vw" quality={90}/></div>
        <div className={s.heroShade}/>
        <div className={s.heroCopy}>
          <h1 id="hero-title">Fundraise<br/>Like a <span>Boss.</span></h1>
          <p className={s.heroBenefit}>Raise money. Help cover family costs.<br className={s.desktopBreak}/> Keep your community connected.</p>
          <p className={s.heroAudience}>For teams, schools, churches, camps<br className={s.desktopBreak}/> and community organizations.</p>
          <div className={s.heroActions}><Link className={s.primary} href="/fundraising/get-started">Start Fundraising</Link><a className={s.secondary} href="#ecosystem">Explore The Boss</a></div>
        </div>
      </section>
      <section id="ecosystem" className={s.ecosystem} aria-labelledby="ecosystem-title">
        <div className={s.ecosystemHeading}><h2 id="ecosystem-title">The Boss <span>Ecosystem</span></h2><p>Start with what you need. Grow with The Boss.</p></div>
        <div className={s.pillars}>{pillars.map(pillar => <Link className={s.pillar} href={pillar.href} key={pillar.title}>
          <div className={s.pillarIntro}><span className={s.pillarIcon}><PillarIcon kind={pillar.icon}/></span><div><h3>{pillar.title}<br/>Like a Boss.</h3><p>{pillar.description}</p></div></div>
          <ReferencePhoto crop={pillar.crop} alt={pillar.alt} className={s.pillarPhoto}/>
        </Link>)}</div>
      </section>
    </main>
  </div>;
}
