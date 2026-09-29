import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Boss Engage"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}><div className={s.eyebrow}>BOSS ENGAGE</div><h1>Engage like a Boss.</h1><p>One connected operating experience for the people who make teams and organizations work: players, families, coaches, volunteers, leaders and supporters.</p><div className={s.actions}><a href="/get-started">Request a Demo →</a><a href="/family-hub">Explore Family Hub</a></div></div>
      <div className={s.photoStage}><img src="https://images.unsplash.com/photo-1771308378506-7f394413342c?auto=format&fit=crop&w=1600&q=84" alt="Youth basketball team huddle with coach"/><div className={s.photoLabel}><small>SPORTS OPERATIONS + FAMILY EXPERIENCE</small><strong>Keep everyone connected to what matters.</strong></div></div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>THE TEAM OPERATING EXPERIENCE</div><h2>Schedules, chat, registrations and more in one place.</h2></div><p>Boss Engage is designed to feel like one coherent app instead of a collection of disconnected utilities.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.engageStack}>
            <div className={s.engageCard}><h4>Upcoming Schedule</h4><div className={s.engageItem}><b>Practice</b><span>Tue 5:30 PM</span></div><div className={s.engageItem}><b>Team Meeting</b><span>Thu 6:30 PM</span></div><div className={s.engageItem}><b>Game vs. Westfield</b><span>Sat 7:00 PM</span></div></div>
            <div className={s.engageCard}><h4>Team Chat</h4><div className={s.engageItem}><b>Coach Martinez</b><span>See you at practice tomorrow.</span></div><div className={s.engageItem}><b>Team Mom</b><span>Snack signup is open.</span></div><div className={s.engageItem}><b>Registration</b><span>Summer skills camp opens Friday.</span></div></div>
            <div className={s.engageCard}><h4>Player Profile</h4><div className={s.engageItem}><b>Marcus Johnson</b><span>#23 · WR</span></div><div className={s.engageItem}><b>Attendance</b><span>92%</span></div><div className={s.engageItem}><b>Badges</b><span>5 earned</span></div></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>REGISTRATIONS</b><h3>Simple signups. Less admin.</h3><p>Programs, fees, waivers and participation details can live inside one cleaner flow.</p></article>
            <article className={s.card}><b>DOCUMENTS</b><h3>Keep important files organized.</h3><p>Future role-aware document handling can support physicals, releases and organization forms securely.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>Keep everyone moving in the same direction.</h2><p>Boss Engage brings the operational pieces together so organizations can spend less time chasing information and more time building community.</p><div className={s.cards}><article className={s.card}><b>OPERATIONS</b><h3>Schedules, rosters and registrations.</h3><p>Manage the practical work around seasons, teams, practices, games, fees and participation.</p></article><article className={s.card}><b>COMMUNICATION</b><h3>Keep people informed.</h3><p>Announcements, group messaging, notifications and team pages keep the right people connected.</p></article><article className={s.card}><b>DOCUMENTS</b><h3>One organized place.</h3><p>Support future secure handling of physicals, waivers and organization documents with role-aware access.</p></article></div></section>

    <section className={s.dark}><h2>Sports operations with a bigger ecosystem behind them.</h2><p>Engage connects naturally to fundraising, family accounts, team stores, supporters, rewards and Boss Bucks.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Organize</h3><p>Structure organizations, seasons, divisions and teams.</p></div><div className={s.step}><span>02</span><h3>Register</h3><p>Bring players and families into a clean participation flow.</p></div><div className={s.step}><span>03</span><h3>Communicate</h3><p>Keep schedules, updates and responsibilities visible.</p></div><div className={s.step}><span>04</span><h3>Grow</h3><p>Connect engagement to fundraising, rewards and community support.</p></div></div></section>
    <section className={s.cta}><h2>Connect. Organize. Grow.</h2><a href="/get-started">Request a Demo →</a></section>
    <SiteFooter/>
  </main>
}
