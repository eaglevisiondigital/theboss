import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Boss Money Board"};

export default function Page(){
  const tiles=["$1","$5","$10","$20","$25","$50","$75","$100","$125","$150","$200","$250"];
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}><div className={s.eyebrow}>BOSS MONEY BOARD</div><h1>Give like a Boss.</h1><p>A visual fundraising experience that turns a goal into simple, understandable giving opportunities supporters can fund one amount at a time.</p><div className={s.actions}><a href="/get-started">Start a Money Board →</a><a href="/fundraising">Boss Fundraising</a></div></div>
      <div className={s.photoStage}><img src="https://images.unsplash.com/photo-1755599629285-91cc09a185c7?auto=format&fit=crop&w=1600&q=84" alt="Community volunteers working together"/><div className={s.photoLabel}><small>SMALL STEPS. BIG IMPACT.</small><strong>Make progress visible from the first gift.</strong></div></div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>SIGNATURE FUNDRAISING EXPERIENCE</div><h2>Watch the board fill in real time.</h2></div><p>The Money Board can operate on its own or become part of a larger Boss fundraising campaign with participant pages, attribution, direct giving and digital savings.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.boardMock}>
            <div className={s.boardMockHeader}><div><small>RIVERSIDE TIGERS</small><strong>Money Board</strong></div><b>68%</b></div>
            <div className={s.mockStats}><div><small>RAISED</small><strong>$3,420</strong></div><div><small>GOAL</small><strong>$5,000</strong></div><div><small>SUPPORTERS</small><strong>32</strong></div></div>
            <div className={s.boardTiles}>{tiles.map((v,i)=><span key={v} className={[4,7,10].includes(i)?s.funded:""}>{v}</span>)}</div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>DONATE MODE</b><h3>Choose an amount and make an impact.</h3><p>Supporters can select available amounts while funded amounts remain permanently claimed.</p></article>
            <article className={s.card}><b>SPIN MODE</b><h3>Add energy to the experience.</h3><p>A randomized selection option can make participation fun while still respecting the configured board rules.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>Small steps can create big impact.</h2><p>Administrators choose the fundraising goal, starting amount and increment. The builder can calculate the board structure and estimated economics before launch.</p><div className={s.cards}><article className={s.card}><b>AVAILABLE</b><h3>Open amounts are clear.</h3><p>Supporters can immediately see which amounts are still available to fund.</p></article><article className={s.card}><b>RESERVED</b><h3>Protect in-progress giving.</h3><p>Reserved states help prevent conflicting selections while a supporter completes checkout.</p></article><article className={s.card}><b>FUNDED</b><h3>Celebrate every contribution.</h3><p>Paid amounts become permanently funded and can display donor or anonymous attribution where appropriate.</p></article></div></section>

    <section className={s.dark}><h2>Built to work alone or with the full campaign.</h2><p>Money Board can operate as the signature fundraiser or alongside Boss Bucks, direct donations and other Boss fundraising products.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Set the Goal</h3><p>Choose the campaign target and board structure.</p></div><div className={s.step}><span>02</span><h3>Launch</h3><p>Share the organization, team or participant fundraising experience.</p></div><div className={s.step}><span>03</span><h3>Fund</h3><p>Supporters choose an available amount and complete giving.</p></div><div className={s.step}><span>04</span><h3>Track</h3><p>Progress, participation and attribution remain visible as the board fills.</p></div></div></section>
    <section className={s.cta}><h2>Turn generosity into visible progress.</h2><a href="/get-started">Create a Money Board →</a></section>
    <SiteFooter/>
  </main>
}
