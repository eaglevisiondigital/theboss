import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"How It Works"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}>
        <div className={s.eyebrow}>HOW IT WORKS</div>
        <h1>Start where you are. Grow from there.</h1>
        <p>Boss connects fundraising, savings, engagement and family participation so every audience can enter through the path that makes sense for them.</p>
        <div className={s.actions}><a href="/get-started">Find Your Path →</a><a href="/">Explore the Ecosystem</a></div>
      </div>
      <div className={s.photoStage}>
        <img src="https://images.unsplash.com/photo-1755599629285-91cc09a185c7?auto=format&fit=crop&w=1600&q=84" alt="People working together on a community project"/>
        <div className={s.photoLabel}><small>START WITH ONE NEED.</small><strong>Let the ecosystem create more value over time.</strong></div>
      </div>
    </section>

    <section className={s.panel}><h2>Start with the need in front of you.</h2><p>You do not have to use every Boss product at once. Teams and organizations can begin with the tool they need now and add more as the relationship grows.</p><div className={s.cards}><article className={s.card}><b>RAISE</b><h3>Launch a fundraising campaign.</h3><p>Use Boss Fundraising, Money Board, digital discounts, direct donations or a combination.</p></article><article className={s.card}><b>ENGAGE</b><h3>Bring people into one experience.</h3><p>Use Boss Engage and Family Hub to connect operations, families and supporters.</p></article><article className={s.card}><b>CONTINUE</b><h3>Keep the relationship alive.</h3><p>Boss Bucks and future ecosystem value give supporters reasons to stay connected after the fundraiser ends.</p></article></div></section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>THE FLYWHEEL</div><h2>Every part can strengthen the next.</h2></div><p>The strategic advantage is not one feature. It is the compounding value created as organizations bring in supporters, supporters discover merchants, families stay engaged and organizations return for more.</p></div>
      <div className={s.steps}><div className={s.step}><span>01</span><h3>Organization Joins</h3><p>A team or organization starts with fundraising or engagement.</p></div><div className={s.step}><span>02</span><h3>Supporters Enter</h3><p>People register through participant links, QR codes or public campaign pages.</p></div><div className={s.step}><span>03</span><h3>Value Continues</h3><p>Digital savings, Family Hub and future ecosystem features extend the relationship.</p></div><div className={s.step}><span>04</span><h3>Community Compounds</h3><p>More organizations, families and merchants make the network more useful for everyone.</p></div></div>
    </section>

    <section className={s.cta}><h2>One ecosystem. Multiple ways to make an impact.</h2><a href="/get-started">Get Started →</a></section>
    <SiteFooter/>
  </main>
}
