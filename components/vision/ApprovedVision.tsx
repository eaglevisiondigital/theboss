import Image from "next/image";
import Link from "next/link";
import ApprovedHeader from "@/components/ApprovedHeader";
import ApprovedFooter from "@/components/ApprovedFooter";
import home from "@/app/approvedHome.module.css";
import s from "./vision.module.css";

// Approved Vision composition; photographic regions reuse the owner-approved artwork.
function Photo({crop,alt}:{crop:string;alt:string}) {
  return <svg viewBox={crop} preserveAspectRatio="xMidYMid slice" role="img" aria-label={alt}><image href="/design/vision-approved.png" width="821" height="1916"/></svg>;
}
function Icon({kind}:{kind:"people"|"growth"|"heart"}) {
  return <svg viewBox="0 0 32 32" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">{kind==="growth"?<><path d="M5 27V18h5v9M14 27V11h5v16M23 27V4h5v23"/></>:kind==="heart"?<path d="M16 27 4 15C-3 5 10 0 16 9 22 0 35 5 28 15Z"/>:<><circle cx="16" cy="8" r="4"/><path d="M9 28v-8c0-7 14-7 14 0v8ZM3 26v-7M29 26v-7"/><circle cx="4" cy="11" r="3"/><circle cx="28" cy="11" r="3"/></>}</svg>;
}
export default function ApprovedVision(){return <div className={home.home}><a className={home.skipLink} href="#main-content">Skip to content</a><ApprovedHeader/><main id="main-content" className={s.page}>
<section className={s.hero}><div className={s.heroCopy}><p className={s.eyebrow}>THE BOSS VISION</p><h1>Equip this generation.<br/>Empower <span>their potential.</span></h1><p>Help young people discover their abilities, pursue their dreams, and see possibilities beyond their circumstances.</p><a href="#our-purpose" className={s.button}>Be part of the vision</a></div><div className={s.heroPhoto}><Image src="/images/approved/vision-hero.png" alt="Young basketball and softball players with a supportive family outside a community recreation center" fill priority sizes="100vw"/></div></section>
<section id="our-purpose" className={s.mission}><h2>Their potential drives our purpose.</h2><p>We created Boss to help equip this generation with practical fundraising tools, meaningful engagement, and a community of support. Together, we can help young people maximize their abilities and build a future filled with opportunity.</p><div className={s.three}>{([
["growth","Unlock opportunity.","Help remove financial barriers and expand what's possible."],
["heart","Build confidence.","Give young people the support they need to pursue their goals."],
["people","Strengthen community.","Bring people together to invest in the next generation."]
] as const).map(([kind,title,copy])=><article key={title}><Icon kind={kind}/><h3>{title}</h3><p>{copy}</p></article>)}</div></section>
<section className={s.family}><div className={s.familyPhoto}><Photo crop="0 605 434 295" alt="A mother and three children preparing for basketball and music activities at home"/></div><div className={s.familyCopy}><h2>More opportunity.<br/>For every family.</h2><p>One child or several. Every background. Every financial starting point. Our vision is to help families overcome financial barriers so more young people can participate, grow, and pursue what they love.</p><ul className={s.costs}>{["Fees & registration","Gear & equipment","Camps & tournaments","Eligible travel"].map(item=><li key={item}>{item}</li>)}</ul><p>Practical ways to raise funds and apply earned Boss Bucks toward approved costs.</p></div></section>
<section className={s.community}><h2>Big dreams deserve a community behind them.</h2><p>Families, coaches, schools, churches, ministries, missions teams, and local businesses all have a part to play.</p><div className={s.three}>{[
["19 982 254 213","Young musicians practicing violin together","Encourage their gifts."],
["285 982 249 213","An adult and teenage volunteer packing supplies for community outreach","Support their purpose."],
["547 982 255 213","A female coach encouraging a girls soccer team","Open more doors."]
].map(([crop,alt,caption])=><figure key={caption}><Photo crop={crop} alt={alt}/><figcaption>{caption}</figcaption></figure>)}</div></section>
<section className={s.founder}><div className={s.years}><strong>30+</strong><h3>Years helping organizations fund opportunity</h3></div><div><p className={s.eyebrow}>THE EXPERIENCE BEHIND BOSS</p><h2>Built on experience. Driven by purpose.</h2><p><b>Dave Fowler</b> | Founder, The Boss</p><p>For more than 30 years, Dave Fowler has helped churches, youth groups, high school and college sports programs, club teams, and missions teams raise the resources to pursue their goals.</p><p>As a college and high school basketball coach and college athletic director, his work has included funding university athletic department budgets through fundraising and corporate sponsorship, and helping organizations raise millions of dollars.</p><p>Boss brings those time-tested approaches together with modern technology to equip today&apos;s families, leaders, and communities.</p></div></section>
<section className={s.ecosystem}><h2>Experience meets possibility.</h2><p>The tools work together. The purpose stays the same.</p><div className={s.three}>{([
["growth","Fundraise Like a Boss.","Create practical ways to fund participation and organizational goals.","/fundraising"],
["heart","Save Like a Boss.","Connect useful discounts with earned value for approved family expenses.","/boss-bucks"],
["people","Engage Like a Boss.","Bring teams, organizations, and family life closer together.","/engage"]
] as const).map(([kind,title,copy,href])=><article key={title}><Icon kind={kind}/><h3><Link href={href}>{title}</Link></h3><p>{copy}</p></article>)}</div><p className={s.note}>Platform vision shown. Feature availability varies by module and rollout.</p><Link href="/family-hub" className={s.hub}><strong>Multiple kids. Multiple teams. Multiple organizations. One Family Hub.</strong><span>Connected calendars, individual fundraising progress, and a shared family view.</span></Link></section>
<section className={s.cta}><div><h2>Help make their next opportunity possible.</h2><p>Bring Boss to your team, ministry, school, or community organization.</p></div><Link href="/get-started" className={s.button}>Get Started</Link></section>
</main><ApprovedFooter/></div>}
