import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";

const products = [
  {k:"01", name:"Boss Bucks Discounts", line:"Save like a Boss.", desc:"Digital savings that connect supporters to local, regional and nationwide value.", cta:"Explore Boss Bucks", href:"/boss-bucks"},
  {k:"02", name:"Boss Fundraising", line:"Fundraise like a Boss.", desc:"Modern campaigns for teams, schools, youth groups, nonprofits and community organizations.", cta:"Raise More", href:"/fundraising"},
  {k:"03", name:"Boss Money Board", line:"Give like a Boss.", desc:"A visual fundraising experience built to turn small steps into measurable progress.", cta:"See Money Board", href:"/money-board"},
  {k:"04", name:"Boss Engage", line:"Engage like a Boss.", desc:"Schedules, registrations, communication, documents, rosters and community in one connected experience.", cta:"Meet Boss Engage", href:"/engage"},
  {k:"05", name:"Boss Family Hub", line:"Keep it all together like a Boss.", desc:"One family account across children, teams, organizations, schedules, fundraising and rewards.", cta:"Explore Family Hub", href:"/family-hub"}
];

const communityHero = "https://images.unsplash.com/photo-1786604455362-321b116175a4?auto=format&fit=crop&w=2200&q=86";
const sportsPhoto = "https://images.unsplash.com/photo-1771308378506-7f394413342c?auto=format&fit=crop&w=1600&q=84";
const volunteerPhoto = "https://images.unsplash.com/photo-1755599629285-91cc09a185c7?auto=format&fit=crop&w=1600&q=84";
const familyPhoto = "https://images.unsplash.com/photo-1770155591037-089cd17697a0?auto=format&fit=crop&w=1600&q=84";

export default function Home() {
  return (
    <main>
      <SiteHeader/>

      <section className="hero hero-photo" id="top">
        <img className="hero-photo-bg" src={communityHero} alt="People gathering together outdoors in warm evening light" />
        <div className="hero-photo-overlay"/>
        <div className="hero-content">
          <div className="eyebrow">THE BOSS ECOSYSTEM</div>
          <h1>Stronger communities.<br/><span>Brighter tomorrows.</span></h1>
          <p className="hero-copy">
            One connected ecosystem for saving money, raising money, engaging people and creating more opportunity for teams, organizations and families.
          </p>
          <div className="hero-actions">
            <a className="button primary" href="/get-started">Get Started <span>→</span></a>
            <a className="button secondary" href="#ecosystem">Explore the Ecosystem</a>
          </div>
          <div className="hero-proof" aria-label="Core platform pillars">
            <span>Save Money</span><i/>
            <span>Raise Money</span><i/>
            <span>Build Community</span><i/>
            <span>Create Opportunity</span>
          </div>
        </div>

        <div className="hero-floating">
          <div className="hero-float-label">ONE APP. MORE WAYS TO MAKE A DIFFERENCE.</div>
          <div className="hero-float-grid">
            <div><small>SAVE</small><strong>Boss Bucks</strong></div>
            <div><small>RAISE</small><strong>Fundraising</strong></div>
            <div><small>ENGAGE</small><strong>Boss Engage</strong></div>
          </div>
        </div>
      </section>

      <section className="visual-story">
        <article className="visual-card visual-card-wide">
          <img src={sportsPhoto} alt="Youth basketball team and coach huddled together" />
          <div className="visual-card-shade"/>
          <div className="visual-card-copy">
            <span>SPORTS TEAMS</span>
            <h2>Organize your sports team like a Boss.</h2>
            <a href="/sports-teams">Explore Sports Teams →</a>
          </div>
        </article>
        <article className="visual-card">
          <img src={volunteerPhoto} alt="Volunteers organizing boxes for community distribution" />
          <div className="visual-card-shade"/>
          <div className="visual-card-copy">
            <span>ORGANIZATIONS</span>
            <h2>Build community like a Boss.</h2>
            <a href="/organizations">Explore Organizations →</a>
          </div>
        </article>
        <article className="visual-card">
          <img src={familyPhoto} alt="Children watching and supporting a youth sports game" />
          <div className="visual-card-shade"/>
          <div className="visual-card-copy">
            <span>FAMILIES</span>
            <h2>Keep it all together like a Boss.</h2>
            <a href="/family-hub">Explore Family Hub →</a>
          </div>
        </article>
      </section>

      <section className="section light" id="ecosystem">
        <div className="section-head">
          <div>
            <div className="eyebrow dark">ONE PLATFORM. MULTIPLE WAYS TO GROW.</div>
            <h2>The ecosystem is the advantage.</h2>
          </div>
          <p>Every product can stand on its own, but the bigger opportunity happens when fundraising, discounts, engagement and family participation work together.</p>
        </div>
        <div className="product-grid">
          {products.map((p)=>(
            <article className="product-card" key={p.name}>
              <div className="product-number">{p.k}</div>
              <div className="product-icon-slot" aria-hidden="true">B+</div>
              <h3>{p.name}</h3>
              <div className="product-line">{p.line}</div>
              <p>{p.desc}</p>
              <a href={p.href}>{p.cta} <span>→</span></a>
            </article>
          ))}
        </div>
      </section>

      <section className="impact-banner">
        <img src={volunteerPhoto} alt="Community volunteers working together" />
        <div className="impact-banner-overlay"/>
        <div className="impact-banner-copy">
          <div className="eyebrow">REAL PEOPLE. REAL IMPACT.</div>
          <h2>Different organizations. Same mission. A brighter tomorrow.</h2>
          <p>Boss is built to help people fund what matters, connect their communities and create more opportunity long after one campaign ends.</p>
        </div>
      </section>

      <section className="split-section" id="fundraising">
        <div className="split-copy">
          <div className="eyebrow">BOSS FUNDRAISING</div>
          <h2>Fundraising should build more than a campaign total.</h2>
          <p>
            Boss helps organizations raise now while building a connected supporter base for what comes next.
          </p>
          <div className="feature-list">
            <div><b>01</b><span><strong>Participant attribution</strong>Every link and QR code can connect support to the right person and organization.</span></div>
            <div><b>02</b><span><strong>Digital Money Board</strong>Visual giving with available, reserved and funded amounts.</span></div>
            <div><b>03</b><span><strong>Digital membership</strong>Supporters can move directly into Boss Bucks access and future renewals.</span></div>
            <div><b>04</b><span><strong>More ways to support</strong>Donations, digital savings, merchandise and future campaign products.</span></div>
          </div>
          <a className="button primary" href="/fundraising/get-started">Start a Fundraiser <span>→</span></a>
        </div>
        <div className="fundraising-visual-stack">
          <div className="fundraising-photo">
            <img src={sportsPhoto} alt="Coach leading a youth basketball team huddle" />
            <div className="fundraising-photo-label"><span>TEAMS RAISE MORE</span><strong>People rally around people.</strong></div>
          </div>
          <div className="money-board">
            <div className="board-top">
              <div><small>RIVERSIDE TIGERS</small><strong>Digital Money Board</strong></div>
              <span>68% Funded</span>
            </div>
            <div className="progress"><i/></div>
            <div className="money-stats">
              <div><small>RAISED</small><strong>$3,420</strong></div>
              <div><small>GOAL</small><strong>$5,000</strong></div>
            </div>
            <div className="amount-grid">
              {["$1","$5","$10","$20","$25","$50","$75","$100","$125","$150","$200","$250"].map((v,i)=>
                <div className={i===4||i===7||i===10?"claimed":""} key={v}>{v}{(i===4||i===7||i===10)&&<small>FUNDED</small>}</div>
              )}
            </div>
            <div className="board-actions"><button>Donate</button><button className="outline">Spin</button></div>
          </div>
        </div>
      </section>

      <section className="section dark-section" id="audiences">
        <div className="section-head">
          <div>
            <div className="eyebrow">WHO BOSS IS FOR</div>
            <h2>One platform. Many ways to belong.</h2>
          </div>
          <p>Boss is broader than sports. Teams, schools, youth groups, nonprofits, families, supporters and merchants can each enter through the experience that fits them.</p>
        </div>
        <div className="audience-photo-grid">
          <a href="/sports-teams" className="audience-photo-card"><img src={sportsPhoto} alt="Youth sports team"/><span>Sports Teams</span></a>
          <a href="/organizations" className="audience-photo-card"><img src={volunteerPhoto} alt="Community volunteers"/><span>Organizations</span></a>
          <a href="/family-hub" className="audience-photo-card"><img src={familyPhoto} alt="Family supporting youth sports"/><span>Families & Supporters</span></a>
        </div>
      </section>

      <section className="section light" id="merchants">
        <div className="merchant-panel merchant-panel-image">
          <div>
            <div className="eyebrow dark">MERCHANTS & DISCOUNTS</div>
            <h2>Support local. Get discovered. Create value.</h2>
            <p>Boss Bucks helps participating merchants become part of the value families and supporters receive from the ecosystem.</p>
            <a className="button primary" href="/merchant-partner">Become a Merchant Partner <span>→</span></a>
          </div>
          <div className="merchant-orbit">
            <div className="orbit-center">B+</div>
            <span className="o1">DINING</span><span className="o2">TRAVEL</span><span className="o3">AUTO</span><span className="o4">FAMILY</span>
          </div>
        </div>
      </section>

      <section className="cta-band" id="start">
        <div>
          <div className="eyebrow">PEOPLE. PURPOSE. POSSIBILITIES.</div>
          <h2>Ready to do it like a Boss?</h2>
          <p>Tell us who you are and what you want to accomplish. We’ll help you find the right path.</p>
        </div>
        <div className="cta-actions">
          <a className="button white" href="/get-started">Get Started <span>→</span></a>
          <a className="button ghost" href="/get-started">Request a Demo</a>
        </div>
      </section>

      <SiteFooter/>
    </main>
  );
}
