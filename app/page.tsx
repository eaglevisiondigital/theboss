const products = [
  {k:"01", name:"Boss Bucks Discounts", line:"Save like a Boss.", desc:"Digital savings that connect supporters to local, regional and nationwide value.", cta:"Explore Boss Bucks"},
  {k:"02", name:"Boss Fundraising", line:"Fundraise like a Boss.", desc:"Modern campaigns for teams, schools, youth groups, nonprofits and community organizations.", cta:"Raise More"},
  {k:"03", name:"Boss Money Board", line:"Give like a Boss.", desc:"A visual fundraising experience built to turn small steps into measurable progress.", cta:"See Money Board"},
  {k:"04", name:"Boss Engage", line:"Engage like a Boss.", desc:"Schedules, registrations, communication, documents, rosters and community in one connected experience.", cta:"Meet Boss Engage"},
  {k:"05", name:"Boss Family Hub", line:"Keep it all together like a Boss.", desc:"One family account across children, teams, organizations, schedules, fundraising and rewards.", cta:"Explore Family Hub"}
];

const paths = [
  ["Sports Teams","Fundraise, operate and grow stronger teams."],
  ["Schools & Groups","Bands, clubs, cheer and student organizations."],
  ["Youth & Community","Youth groups, ministries, nonprofits and local organizations."],
  ["Families & Supporters","Support the people you care about and save along the way."],
  ["Merchants","Reach local customers while supporting the communities around you."]
];

export default function Home() {
  return (
    <main>
      <header className="nav-shell">
        <a className="brand" href="#top" aria-label="BOSS PLUS home">
          <span className="brand-word">BOSS</span><span className="brand-plus">PLUS</span>
        </a>
        <nav aria-label="Primary navigation">
          <a href="#ecosystem">Ecosystem</a>
          <a href="#fundraising">Fundraising</a>
          <a href="#audiences">Who It’s For</a>
          <a href="#merchants">Merchants</a>
        </nav>
        <a className="nav-cta" href="#start">Get Started</a>
      </header>

      <section className="hero" id="top">
        <div className="hero-glow" />
        <div className="eyebrow">THE BOSS ECOSYSTEM</div>
        <h1>Build a stronger<br/><span>tomorrow together.</span></h1>
        <p className="hero-copy">
          One connected ecosystem for saving money, raising money, engaging people and creating more opportunity for teams, organizations and families.
        </p>
        <div className="hero-actions">
          <a className="button primary" href="#start">Get Started <span>→</span></a>
          <a className="button secondary" href="#ecosystem">Explore the Ecosystem</a>
        </div>
        <div className="hero-proof" aria-label="Core platform pillars">
          <span>Save Money</span><i/>
          <span>Raise Money</span><i/>
          <span>Build Community</span><i/>
          <span>Create Opportunity</span>
        </div>
        <div className="hero-stage" aria-label="BOSS PLUS product presentation">
          <div className="stage-grid">
            <div className="stage-main">
              <div className="stage-label">ONE APP. MORE WAYS TO MAKE A DIFFERENCE.</div>
              <div className="stage-title">People. Purpose.<br/>Possibilities.</div>
            </div>
            <div className="stage-card">
              <div className="mini-label">BOSS FUNDRAISING</div>
              <strong>More ways to raise.</strong>
              <p>Digital-first campaigns with participant attribution, direct giving and Money Board.</p>
            </div>
            <div className="stage-card">
              <div className="mini-label">BOSS BUCKS</div>
              <strong>Value that continues.</strong>
              <p>Turn fundraiser supporters into long-term digital members with meaningful savings.</p>
            </div>
          </div>
        </div>
      </section>

      <section className="section light" id="ecosystem">
        <div className="section-head">
          <div>
            <div className="eyebrow dark">ONE PLATFORM. MULTIPLE WAYS TO GROW.</div>
            <h2>The ecosystem is the advantage.</h2>
          </div>
          <p>Every product is designed to stand on its own and become more valuable when it works with the rest of Boss.</p>
        </div>
        <div className="product-grid">
          {products.map((p)=>(
            <article className="product-card" key={p.name}>
              <div className="product-number">{p.k}</div>
              <div className="product-icon-slot" aria-hidden="true">B+</div>
              <h3>{p.name}</h3>
              <div className="product-line">{p.line}</div>
              <p>{p.desc}</p>
              <a href="#start">{p.cta} <span>→</span></a>
            </article>
          ))}
        </div>
      </section>

      <section className="split-section" id="fundraising">
        <div className="split-copy">
          <div className="eyebrow">BOSS FUNDRAISING</div>
          <h2>Fundraising should build more than a campaign total.</h2>
          <p>
            Boss is being designed to help organizations raise now while building a connected supporter base for what comes next.
          </p>
          <div className="feature-list">
            <div><b>01</b><span><strong>Participant attribution</strong>Every link and QR code can connect support to the right person and organization.</span></div>
            <div><b>02</b><span><strong>Digital Money Board</strong>Visual giving with available, reserved and funded amounts.</span></div>
            <div><b>03</b><span><strong>Digital membership</strong>Supporters can move directly into Boss Bucks access and future renewals.</span></div>
            <div><b>04</b><span><strong>More ways to support</strong>Donations, digital savings, merchandise and future campaign products.</span></div>
          </div>
          <a className="button primary" href="#start">Start a Fundraiser <span>→</span></a>
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
      </section>

      <section className="section dark-section" id="audiences">
        <div className="section-head">
          <div>
            <div className="eyebrow">DIFFERENT ORGANIZATIONS. SHARED MISSION.</div>
            <h2>Find your place in Boss.</h2>
          </div>
          <p>Boss is broader than sports. The platform is built for people and organizations that want to raise, engage and create greater community impact.</p>
        </div>
        <div className="path-grid">
          {paths.map(([title,desc],i)=>(
            <a className="path-card" href="#start" key={title}>
              <span>0{i+1}</span><h3>{title}</h3><p>{desc}</p><b>Explore →</b>
            </a>
          ))}
        </div>
      </section>

      <section className="section light" id="merchants">
        <div className="merchant-panel">
          <div>
            <div className="eyebrow dark">MERCHANTS & DISCOUNTS</div>
            <h2>Support local. Get discovered. Create value.</h2>
            <p>Boss Bucks helps participating merchants become part of the value families and supporters receive from the ecosystem.</p>
            <a className="button primary" href="#start">Become a Merchant Partner <span>→</span></a>
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
          <a className="button white" href="mailto:info@theboss.biz?subject=Boss%20Get%20Started">Get Started <span>→</span></a>
          <a className="button ghost" href="mailto:info@theboss.biz?subject=Boss%20Demo">Request a Demo</a>
        </div>
      </section>

      <footer>
        <div className="footer-brand"><b>BOSS <span>PLUS</span></b><small>THE BOSS ECOSYSTEM</small></div>
        <div className="footer-copy">Stronger communities. Brighter tomorrows.</div>
        <div className="footer-meta">© 2026 BOSS PLUS. All rights reserved.</div>
      </footer>
    </main>
  );
}
