import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Merchants & Discounts"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}>
        <div className={s.eyebrow}>MERCHANTS & DISCOUNTS</div>
        <h1>Support local. Get discovered.</h1>
        <p>Join the Boss Bucks merchant network and create meaningful value for families, supporters, teams and organizations in the communities you serve.</p>
        <div className={s.actions}><a href="/merchant-partner">Become a Merchant Partner →</a><a href="/boss-bucks">See Boss Bucks</a></div>
      </div>
      <div className={s.photoStage}>
        <img src="https://images.unsplash.com/photo-1721238026871-760ff15739dc?auto=format&fit=crop&w=1600&q=84" alt="Customers enjoying a local restaurant"/>
        <div className={s.photoLabel}><small>LOCAL DEALS. BIGGER VALUE.</small><strong>Be part of the savings people actually use.</strong></div>
      </div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>THE MERCHANT NETWORK</div><h2>Reach people while supporting what matters locally.</h2></div><p>Boss Bucks is designed to create a useful exchange: members get savings, organizations gain more value for supporters, and merchants earn visibility with active local families.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.phone}>
            <div className={s.phoneTop}/>
            <div className={s.appBar}>BOSS BUCKS NEAR YOU</div>
            <div className={s.phoneBody}>
              <div className={s.deal}><small>DINING</small><strong>15% OFF</strong><p>Local restaurant</p><span>1.2 mi</span></div>
              <div className={s.deal}><small>AUTO</small><strong>$10 OFF</strong><p>Oil change & service</p><span>3.1 mi</span></div>
              <div className={s.deal}><small>FAMILY</small><strong>BOGO</strong><p>Entertainment venue</p><span>4.8 mi</span></div>
            </div>
            <div className={s.phoneNav}><span>Home</span><span>Deals</span><span>Near Me</span><span>Favorites</span><span>Account</span></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>FLEXIBLE OFFERS</b><h3>Create value that fits your business.</h3><p>Percentage discounts, dollar-off offers, BOGO, free items and special pricing can all fit within a structured merchant offer system.</p></article>
            <article className={s.card}><b>GROW YOUR REACH</b><h3>Local today. Multi-location tomorrow.</h3><p>The architecture is designed to support one location, metro groups, regional businesses and eventually national brands.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>A better reason to be part of the community.</h2><p>Boss Bucks is designed to help merchants support local organizations while giving members a practical reason to visit, save and come back.</p><div className={s.cards}><article className={s.card}><b>VISIBILITY</b><h3>Reach active local supporters.</h3><p>Participating businesses can be discovered by Boss Bucks members looking for useful places to save.</p></article><article className={s.card}><b>FLEXIBLE OFFERS</b><h3>Create value that fits your business.</h3><p>Future merchant tools can support percentage discounts, dollar-off offers, special pricing and other approved offer structures.</p></article><article className={s.card}><b>MULTI-LOCATION</b><h3>Grow from local to national.</h3><p>The merchant architecture is being designed for single locations, metro groups, regional businesses and national brands.</p></article></div></section>

    <section className={s.dark}><h2>Built to become a real merchant network.</h2><p>The long-term experience can support merchant onboarding, offer management, location coverage, sponsorships and campaign partnerships without changing the consumer-facing Boss Bucks identity.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Apply</h3><p>Tell us about your business, locations and proposed offer.</p></div><div className={s.step}><span>02</span><h3>Approve</h3><p>Boss reviews fit, offer structure and eligible locations.</p></div><div className={s.step}><span>03</span><h3>Launch</h3><p>Your approved offer can become available to eligible Boss Bucks members.</p></div><div className={s.step}><span>04</span><h3>Grow</h3><p>Future tools can expand reach, featured placement and team partnerships.</p></div></div></section>
    <section className={s.cta}><h2>Partner like a Boss.</h2><a href="/merchant-partner">Become a Merchant Partner →</a></section>
    <SiteFooter/>
  </main>
}
