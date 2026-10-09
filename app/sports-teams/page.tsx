import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Sports Teams"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}>
        <div className={s.eyebrow}>SPORTS TEAMS</div>
        <h1>More than champions.</h1>
        <p>Boss helps sports teams raise money, stay organized, engage families and build stronger communities through one connected ecosystem.</p>
        <div className={s.actions}><a href="/fundraising/get-started">Get Started →</a><a href="/engage">Explore Boss Engage</a></div>
      </div>
      <div className={s.photoStage}>
        <img src="https://images.unsplash.com/photo-1771308378506-7f394413342c?auto=format&fit=crop&w=1600&q=84" alt="Youth basketball team huddled with coach"/>
        <div className={s.photoLabel}><small>SAME TEAMS. BIGGER POSSIBILITIES.</small><strong>Raise. Organize. Engage. Grow.</strong></div>
      </div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>THE FULL TEAM EXPERIENCE</div><h2>Everything around the season can live in one ecosystem.</h2></div><p>Fundraising, registrations, schedules, documents, family participation, rewards and team merchandise all become stronger when they connect instead of living in separate tools.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.engageStack}>
            <div className={s.engageCard}><h4>Team Schedule</h4><div className={s.engageItem}><b>Practice</b><span>Tue · 5:30 PM</span></div><div className={s.engageItem}><b>Game vs. Central</b><span>Fri · 7:00 PM</span></div><div className={s.engageItem}><b>Team Meeting</b><span>Sun · 4:00 PM</span></div></div>
            <div className={s.engageCard}><h4>Roster</h4><div className={s.engageItem}><b>Marcus Johnson</b><span>#23 · WR</span></div><div className={s.engageItem}><b>Ethan Smith</b><span>#11 · RB</span></div><div className={s.engageItem}><b>Jordan Davis</b><span>#5 · QB</span></div></div>
            <div className={s.engageCard}><h4>Fundraising</h4><div className={s.engageItem}><b>$6,420 Raised</b><span>64% of goal</span></div><div className={s.engageItem}><b>32 Participants</b><span>87 supporters</span></div><div className={s.engageItem}><b>12 Days Left</b><span>Keep sharing</span></div></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>TEAM STORE</b><h3>Show your pride. Support the mission.</h3><p>Custom apparel, fan gear and organization products can become another revenue and engagement channel.</p></article>
            <article className={s.card}><b>REWARDS & BADGES</b><h3>Recognize what matters.</h3><p>Participation, fundraising, leadership and team milestones can become visible and worth celebrating.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>Built around the full team experience.</h2><p>Fundraising is only one part of the journey. Boss is designed to support athletes, parents, coaches, athletic directors and supporters before, during and after the season.</p><div className={s.cards}><article className={s.card}><b>FUNDRAISING</b><h3>Raise more with more options.</h3><p>Digital savings, Money Board, direct donations and merchandise can work together in one campaign.</p></article><article className={s.card}><b>TEAM OPERATIONS</b><h3>Keep the season organized.</h3><p>Schedules, rosters, registrations, fees, documents and communication fit naturally inside Boss Engage.</p></article><article className={s.card}><b>FAMILY EXPERIENCE</b><h3>Make participation easier.</h3><p>Family Hub brings multiple children, teams, schedules, fundraising and future Boss Bucks value into one place.</p></article></div></section>

    <section className={s.dark}><h2>Same teams. Bigger possibilities.</h2><p>Boss can serve football, basketball, volleyball, soccer, baseball, softball, cheer, homeschool athletics and other youth sports without forcing every organization into the same mold.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Raise</h3><p>Launch modern fundraising with team and participant attribution.</p></div><div className={s.step}><span>02</span><h3>Organize</h3><p>Manage schedules, registrations, documents and communication.</p></div><div className={s.step}><span>03</span><h3>Reward</h3><p>Use leaderboards, milestones and badges to recognize participation.</p></div><div className={s.step}><span>04</span><h3>Grow</h3><p>Keep families and supporters connected beyond one fundraiser.</p></div></div></section>
    <section className={s.cta}><h2>Organize your sports team like a Boss.</h2><a href="/fundraising/get-started">Start Here →</a></section>
    <SiteFooter/>
  </main>
}
