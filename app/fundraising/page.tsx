import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Boss Fundraising"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}><div className={s.eyebrow}>BOSS FUNDRAISING</div><h1>Fundraise like a Boss.</h1><p>One connected fundraising system for sports teams, school groups, youth organizations, nonprofits and qualifying community organizations.</p><div className={s.actions}><a href="/fundraising/get-started">Start a Fundraiser →</a><a href="/money-board">Explore Money Board</a></div></div>
      <div className={s.photoStage}><img src="https://images.unsplash.com/photo-1771308378506-7f394413342c?auto=format&fit=crop&w=1600&q=84" alt="Youth sports team gathering together"/><div className={s.photoLabel}><small>REAL TEAMS. REAL SUPPORT.</small><strong>Give every supporter more ways to help.</strong></div></div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>ONE CAMPAIGN. MULTIPLE WAYS TO SUPPORT.</div><h2>Build a campaign around people, not one product.</h2></div><p>Boss Fundraising is designed so a supporter can donate, buy digital Boss Bucks, fund a Money Board amount, shop organization merchandise and share the campaign while the right team and participant keep the credit.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.boardMock}>
            <div className={s.boardMockHeader}><div><small>RIVERSIDE TIGERS</small><strong>Fundraising Campaign</strong></div><b>68%</b></div>
            <div className={s.mockStats}><div><small>RAISED</small><strong>$6,420</strong></div><div><small>PARTICIPANTS</small><strong>32</strong></div><div><small>SUPPORTERS</small><strong>87</strong></div></div>
            <div className={s.boardTiles}><span>Donate</span><span>Boss Bucks</span><span>Money Board</span><span>Store</span><span className={s.funded}>Top Seller</span><span>Share</span><span>QR Code</span><span>Rewards</span></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>TEAM + PARTICIPANT ATTRIBUTION</b><h3>Know who created the result.</h3><p>Every participant can have a unique share link and QR code while the organization still sees the complete campaign picture.</p></article>
            <article className={s.card}><b>RECURRING VALUE</b><h3>Turn support into a longer relationship.</h3><p>Digital Boss Bucks access can give supporters a reason to remain connected after the fundraiser ends.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>Give every campaign more ways to win.</h2><p>Boss Fundraising is designed around flexibility. Organizations can combine digital savings, Money Board, direct donations, merchandise and future fundraising products in one campaign architecture.</p><div className={s.cards}><article className={s.card}><b>PARTICIPANT PAGES</b><h3>Credit the right person.</h3><p>Unique links and QR codes support participant-level attribution and individual progress.</p></article><article className={s.card}><b>CAMPAIGN PROGRESS</b><h3>Make momentum visible.</h3><p>Team totals, participant totals, supporters, goals and leaderboards can all reinforce progress.</p></article><article className={s.card}><b>REWARDS</b><h3>Recognize participation.</h3><p>Campaign admins can pair progress with milestones, prizes, badges and recognition.</p></article></div></section>

    <section className={s.dark}><h2>One supporter. Multiple ways to help.</h2><p>The long-term architecture lets a supporter choose the action that fits them while Boss preserves campaign attribution and reporting.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Give</h3><p>Make a direct contribution to the campaign.</p></div><div className={s.step}><span>02</span><h3>Save</h3><p>Purchase or activate Boss Bucks digital discount access.</p></div><div className={s.step}><span>03</span><h3>Fund a Board</h3><p>Select an available amount on a Digital Money Board.</p></div><div className={s.step}><span>04</span><h3>Share</h3><p>Help the team reach more supporters through a personal link.</p></div></div></section>
    <section className={s.cta}><h2>More ways to raise. One connected campaign.</h2><a href="/fundraising/get-started">Start a Fundraiser →</a></section>
    <SiteFooter/>
  </main>
}
