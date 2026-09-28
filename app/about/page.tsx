import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"The Boss Ecosystem"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}>
        <div className={s.eyebrow}>THE BOSS ECOSYSTEM</div>
        <h1>People. Purpose. Possibilities.</h1>
        <p>Boss is being built around a simple idea: give people and organizations more ways to raise, save, connect and create opportunity through one growing platform.</p>
        <div className={s.actions}><a href="/get-started">Get Started →</a><a href="/how-it-works">How It Works</a></div>
      </div>
      <div className={s.photoStage}>
        <img src="https://images.unsplash.com/photo-1786604455362-321b116175a4?auto=format&fit=crop&w=1600&q=84" alt="Community gathered together outdoors"/>
        <div className={s.photoLabel}><small>ONE ECOSYSTEM. MORE WAYS TO MAKE A DIFFERENCE.</small><strong>Stronger communities. Brighter tomorrows.</strong></div>
      </div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}>
        <div><div className={s.eyebrow}>WHY BOSS EXISTS</div><h2>More than a fundraiser. More than an app.</h2></div>
        <p>The opportunity is what happens when organizations, families, supporters and merchants stay connected instead of disappearing after one transaction.</p>
      </div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}><div className={s.boardMock}><div className={s.boardMockHeader}><div><small>THE BOSS ECOSYSTEM</small><strong>One relationship. More value.</strong></div><b>B+</b></div><div className={s.mockStats}><div><small>RAISE</small><strong>Fundraising</strong></div><div><small>SAVE</small><strong>Boss Bucks</strong></div><div><small>ENGAGE</small><strong>Boss Engage</strong></div></div><div className={s.boardTiles}><span>Money Board</span><span>Family Hub</span><span>Stores</span><span>Merchants</span><span>Rewards</span><span>Teams</span><span>Organizations</span><span>Supporters</span></div></div></div>
        <div className={s.devicePanel}><div className={s.cards} style={{gridTemplateColumns:"1fr"}}><article className={s.card}><b>PEOPLE</b><h3>Built around real communities.</h3><p>Athletes, families, coaches, volunteers, merchants and supporters are at the center of the experience.</p></article><article className={s.card}><b>PURPOSE</b><h3>Tools should serve a mission.</h3><p>Every product should make it easier to fund, organize, support or strengthen something that matters.</p></article></div></div>
      </div>
    </section>

    <section className={s.panel}><h2>Different products. One Boss.</h2><p>Boss Bucks Discounts, Boss Fundraising, Boss Money Board, Boss Engage and Boss Family Hub each solve a distinct problem while sharing one larger ecosystem strategy.</p><div className={s.cards}><article className={s.card}><b>SAVE</b><h3>Boss Bucks</h3><p>Ongoing digital value for families and supporters.</p></article><article className={s.card}><b>RAISE</b><h3>Fundraising + Money Board</h3><p>Flexible ways to support teams and organizations.</p></article><article className={s.card}><b>ENGAGE</b><h3>Engage + Family Hub</h3><p>Connected operations and a simpler family experience.</p></article></div></section>
    <section className={s.cta}><h2>A stronger tomorrow together.</h2><a href="/get-started">Get Started →</a></section>
    <SiteFooter/>
  </main>
}
