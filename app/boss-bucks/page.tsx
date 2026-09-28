import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Boss Bucks Discounts"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}>
        <div className={s.eyebrow}>BOSS BUCKS DISCOUNTS</div>
        <h1>Save like a Boss.</h1>
        <p>Digital discounts designed to give supporters real ongoing value while helping teams and organizations build a stronger long-term community around every fundraiser.</p>
        <div className={s.actions}><a href="/get-started">Get Boss Bucks →</a><a href="/fundraising">Use It With Fundraising</a></div>
      </div>
      <div className={s.photoStage}>
        <img src="https://images.unsplash.com/photo-1721238026871-760ff15739dc?auto=format&fit=crop&w=1600&q=84" alt="People enjoying a local restaurant experience"/>
        <div className={s.photoLabel}><small>LOCAL VALUE. REAL SAVINGS.</small><strong>Useful benefits people want to keep using.</strong></div>
      </div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>DIGITAL EXPERIENCE</div><h2>A discount membership built for everyday use.</h2></div><p>The approved Boss Bucks direction is mobile-first, clear, fast and location-aware, with featured deals, nearby savings and an easy path back into the broader Boss ecosystem.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.phone}>
            <div className={s.phoneTop}/>
            <div className={s.appBar}>BOSS BUCKS DISCOUNTS</div>
            <div className={s.phoneBody}>
              <div className={s.deal}><small>FEATURED DEAL</small><strong>20% OFF</strong><p>Local dining favorite</p><span>UNLIMITED USE</span></div>
              <div className={s.deal}><small>NEAR YOU</small><strong>Save $8</strong><p>Family entertainment</p><span>2.4 mi away</span></div>
              <div className={s.deal}><small>LOCAL FAVORITE</small><strong>BOGO</strong><p>Quick-service restaurant</p><span>Nearby</span></div>
            </div>
            <div className={s.phoneNav}><span>Home</span><span>Deals</span><span>Near Me</span><span>Favorites</span><span>Account</span></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div>
            <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
              <article className={s.card}><b>LOCAL / HOME MARKET</b><h3>Start with savings that matter nearby.</h3><p>Home-market access can connect supporters to restaurants, entertainment, services and other participating merchants in the area they actually use.</p></article>
              <article className={s.card}><b>EXPANDABLE ACCESS</b><h3>Local. Metro. Statewide. Nationwide.</h3><p>The platform is designed to support broader geographic access as the merchant network and membership offering grow.</p></article>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>More than a digital discount card.</h2><p>Boss Bucks is being built as a recurring digital membership experience that can grow with supporters beyond the original campaign.</p><div className={s.cards}><article className={s.card}><b>LOCAL VALUE</b><h3>Useful savings close to home.</h3><p>Participating restaurants, services, entertainment and merchants can create everyday reasons to keep using Boss.</p></article><article className={s.card}><b>GEOGRAPHIC ACCESS</b><h3>Local to nationwide.</h3><p>The platform architecture supports home-market access with future metro, statewide and nationwide membership tiers.</p></article><article className={s.card}><b>DIGITAL FIRST</b><h3>Built for renewals.</h3><p>Supporters can register through a team or participant and continue digitally after the fundraiser is over.</p></article></div></section>

    <section className={s.dark}><h2>A fundraiser can be the beginning.</h2><p>Teams can introduce supporters to Boss Bucks through a direct purchase or promotional access period while preserving credit for the organization and participant.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Share</h3><p>A participant shares a unique fundraising link or QR code.</p></div><div className={s.step}><span>02</span><h3>Register</h3><p>The supporter creates an account and attribution stays connected.</p></div><div className={s.step}><span>03</span><h3>Save</h3><p>The supporter activates Boss Bucks and begins using eligible discounts.</p></div><div className={s.step}><span>04</span><h3>Continue</h3><p>Future renewal can extend the relationship well beyond the campaign.</p></div></div></section>
    <section className={s.cta}><h2>Save more. Support more.</h2><a href="/get-started">Get Started →</a></section>
    <SiteFooter/>
  </main>
}
