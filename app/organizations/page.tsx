import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";
import s from "../product.module.css";

export const metadata={title:"Organizations"};

export default function Page(){
  return <main className={s.page}>
    <SiteHeader/>
    <section className={s.visualHero}>
      <div className={s.heroCopy}>
        <div className={s.eyebrow}>ORGANIZATIONS</div>
        <h1>Different organizations. Same mission.</h1>
        <p>Boss gives schools, bands, youth groups, children’s ministries, nonprofits, camps and community organizations more ways to raise, engage and create opportunity.</p>
        <div className={s.actions}><a href="/get-started">Start Your Organization →</a><a href="/fundraising">Explore Fundraising</a></div>
      </div>
      <div className={s.photoStage}>
        <img src="https://images.unsplash.com/photo-1755599629285-91cc09a185c7?auto=format&fit=crop&w=1600&q=84" alt="Volunteers working together in a community project"/>
        <div className={s.photoLabel}><small>FAITH. COMMUNITY. PURPOSE.</small><strong>Equip people. Fund bigger missions.</strong></div>
      </div>
    </section>

    <section className={s.productStage}>
      <div className={s.productStageHead}><div><div className={s.eyebrow}>BUILT BEYOND SPORTS</div><h2>Use the pieces that fit your mission.</h2></div><p>Organizations can begin with fundraising, then expand into events, communication, supporters, stores and family connections without leaving the broader Boss ecosystem.</p></div>
      <div className={s.deviceGrid}>
        <div className={s.devicePanel}>
          <div className={s.boardMock}>
            <div className={s.boardMockHeader}><div><small>RIVERSIDE YOUTH MINISTRY</small><strong>Organization Hub</strong></div><b>124</b></div>
            <div className={s.mockStats}><div><small>PARTICIPANTS</small><strong>124</strong></div><div><small>RAISED</small><strong>$8,620</strong></div><div><small>SUPPORTERS</small><strong>87</strong></div></div>
            <div className={s.boardTiles}><span>Events</span><span>Fundraise</span><span>Messages</span><span>Store</span><span>Volunteers</span><span>Resources</span><span>Donors</span><span>Impact</span></div>
          </div>
        </div>
        <div className={s.devicePanel}>
          <div className={s.cards} style={{gridTemplateColumns:"1fr"}}>
            <article className={s.card}><b>GROUP PAGES</b><h3>Give every organization a digital home.</h3><p>Public-facing pages can help people discover the mission, follow updates and support what the organization is doing.</p></article>
            <article className={s.card}><b>SUPPORTER CONNECTIONS</b><h3>Turn one gift into a longer relationship.</h3><p>Fundraising can become the front door to ongoing engagement, recurring support and future Boss experiences.</p></article>
          </div>
        </div>
      </div>
    </section>

    <section className={s.panel}><h2>One ecosystem. Many kinds of impact.</h2><p>The platform is intentionally broader than sports so organizations can use the pieces that fit their mission without losing the benefit of the larger Boss ecosystem.</p><div className={s.cards}><article className={s.card}><b>SCHOOLS & BANDS</b><h3>Fund programs and participation.</h3><p>Support marching bands, clubs, student groups and school-based fundraising needs.</p></article><article className={s.card}><b>YOUTH & MINISTRIES</b><h3>Build people and community.</h3><p>Help youth groups, children’s organizations, camps and mission teams raise support and stay connected.</p></article><article className={s.card}><b>NONPROFITS & COMMUNITY</b><h3>Create local opportunity.</h3><p>Give qualifying organizations modern tools to raise support and mobilize people around a mission.</p></article></div></section>

    <section className={s.dark}><h2>Use what fits. Add more as you grow.</h2><p>Organizations can begin with fundraising and expand into communication, events, stores, supporters, Family Hub connections and other Boss tools as their needs grow.</p><div className={s.steps}><div className={s.step}><span>01</span><h3>Choose Your Goal</h3><p>Define what the organization needs to fund or accomplish.</p></div><div className={s.step}><span>02</span><h3>Build the Campaign</h3><p>Choose Money Board, digital savings, direct giving and other campaign options.</p></div><div className={s.step}><span>03</span><h3>Engage People</h3><p>Bring participants, families, volunteers and supporters into one experience.</p></div><div className={s.step}><span>04</span><h3>Keep Growing</h3><p>Use the broader ecosystem to deepen relationships after the campaign.</p></div></div></section>
    <section className={s.cta}><h2>Build community like a Boss.</h2><a href="/get-started">Get Started →</a></section>
    <SiteFooter/>
  </main>
}
