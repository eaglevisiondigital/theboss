import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Boss Family Hub"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}><div className={s.eyebrow}>BOSS FAMILY HUB</div><h1>Keep it all together like a Boss.</h1><p>One family account built around real life: multiple children, multiple teams, multiple organizations, one connected place to stay organized.</p><div className={s.actions}><a href="/get-started">Explore Family Hub →</a><a href="/engage">Meet Boss Engage</a></div></div>
      <div className={s.photoStage}><img src="https://images.unsplash.com/photo-1770155591037-089cd17697a0?auto=format&fit=crop&w=1600&q=84" alt="Family supporting youth sports from the sidelines"/><div className={s.photoLabel}><small>ONE FAMILY. MULTIPLE TEAMS.</small><strong>A simpler connected life.</strong></div></div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>FAMILY EXPERIENCE</div><h2>See the whole family, not one team at a time.</h2></div><p>Family Hub is designed for households juggling children, sports, organizations, fundraising, payments and schedules at the same time.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.familyDashboard}>
            <div className={s.familyPanel}><h4>My Family</h4><div className={s.familyChild}><b>Marcus</b><span>Football · Riverside Tigers</span></div><div className={s.familyChild}><b>Jasmine</b><span>Cheer · Riverside Tigers</span></div><div className={s.familyChild}><b>Ethan</b><span>Basketball · Westfield</span></div></div>
            <div className={s.familyPanel}><h4>This Week</h4><div className={s.calendarRows}><div><b>Tue</b><span>Practice 5:30</span></div><div><b>Thu</b><span>Team Meeting 6:30</span></div><div><b>Sat</b><span>Game 7:00</span></div><div><b>Sun</b><span>Fundraiser closes</span></div></div></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>FAMILY WALLET</b><h3>One place to see value and payments.</h3><p>Future Boss Bucks, registrations, fees and approved purchases can become part of one household view.</p></article>
            <article className={s.card}><b>FAMILY CALENDAR</b><h3>Never miss a moment.</h3><p>Bring schedules from different children and organizations into a single family-level calendar.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>One family. More connected experiences.</h2><p>Family Hub is designed to become the household view across Boss, bringing the information and value families care about into one place.</p><div className={s.cards}><article className={s.card}><b>FAMILY CALENDAR</b><h3>See the whole week.</h3><p>Bring schedules from different teams and organizations into a more useful family-level view.</p></article><article className={s.card}><b>FUNDRAISING</b><h3>Know who raised what.</h3><p>See campaign progress and participant impact across the children and organizations connected to the family.</p></article><article className={s.card}><b>BOSS BUCKS</b><h3>Shared ecosystem value.</h3><p>Future closed-loop family Boss Bucks can support approved fees, merchandise, travel and other ecosystem purchases.</p></article></div></section>

    <section className={s.dark}><h2>Built around the way families actually participate.</h2><p>A parent or guardian may be managing several children across sports, schools, churches and community organizations at the same time.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Children</h3><p>Keep each child’s teams, groups and activity organized.</p></div><div className={s.step}><span>02</span><h3>Schedules</h3><p>Bring practices, games and events into the family view.</p></div><div className={s.step}><span>03</span><h3>Payments</h3><p>Future registration, fees and approved ecosystem purchases can live in one experience.</p></div><div className={s.step}><span>04</span><h3>Rewards</h3><p>Connect participation, fundraising and Boss Bucks value over time.</p></div></div></section>
    <section className={s.cta}><h2>One account. A simpler connected life.</h2><a href="/get-started">Get Started →</a></section>
    <SiteFooter/>
  </main>
}
