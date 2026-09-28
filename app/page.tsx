const sportsHero = "https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=2200&q=88";
const football = "https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=1000&q=84";
const youth = "https://images.unsplash.com/photo-1519315901367-f34ff9154487?auto=format&fit=crop&w=1000&q=84";
const school = "https://images.unsplash.com/photo-1509062522246-3755977927d7?auto=format&fit=crop&w=1000&q=84";
const church = "https://images.unsplash.com/photo-1473177104440-ffee2f376098?auto=format&fit=crop&w=1000&q=84";
const community = "https://images.unsplash.com/photo-1559027615-cd4628902d4a?auto=format&fit=crop&w=1000&q=84";
const merchant = "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=84";
const player = "https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=1200&q=84";

const audiences = [
  ["Sports Teams","Build stronger teams on and off the field.",football],
  ["Youth Groups","More than activities. A higher purpose.",youth],
  ["Schools","Support students. Create opportunities.",school],
  ["Churches","Strengthen faith. Build community.",church],
  ["Community Organizations","Local impact. Lasting change.",community]
];

const passions = ["Football","Basketball","Soccer","Volleyball","Softball","Track","Cheer","Band","More"];

export default function Home(){
  return <main className="boss-home">
    <header className="boss-home-nav">
      <a className="boss-home-brand" href="/"><span className="boss-mark">B</span><span><b>THE BOSS</b><small>PEOPLE. PURPOSE. POSSIBILITIES.</small></span></a>
      <nav>
        <a href="/">Home</a><a href="/fundraising">Fundraising</a><a href="/boss-bucks">Boss Bucks</a><a href="/engage">Boss Engage</a><a href="/organizations">Organizations</a><a href="/how-it-works">Resources</a><a href="/contact">Contact</a>
      </nav>
      <div className="boss-home-actions"><a className="demo" href="/get-started">Book a Demo</a><a className="start" href="/get-started">Get Started →</a></div>
    </header>

    <section className="boss-hero">
      <img src={sportsHero} alt="Youth athletes together at sunset"/>
      <div className="boss-hero-shade"/>
      <div className="boss-hero-copy">
        <div className="boss-kicker">THE BOSS ECOSYSTEM</div>
        <h1>FUNDRAISE<br/>LIKE A <span>BOSS.</span></h1>
        <h2>Helping Support, Engage & Empower Kids and Youth.<br/><strong>Investing in Their Future.</strong></h2>
        <div className="boss-hero-pillars">
          <div><i>♥</i><b>Fundraise<br/>Like a Boss.</b></div>
          <div><i>●●●</i><b>Engage<br/>Like a Boss.</b></div>
          <div><i>$</i><b>Save<br/>Like a Boss.</b></div>
        </div>
        <div className="boss-hero-buttons"><a href="/get-started">Get Started →</a><a className="ghost" href="/how-it-works">▶ See How It Works</a></div>
      </div>
      <div className="boss-handwritten">Same Passion.<br/>Bigger<br/>Possibilities.</div>
    </section>

    <section className="boss-audience-strip">
      <div className="boss-section-title"><h2>FOR <span>TEAMS, SCHOOLS, CHURCHES</span> & COMMUNITY ORGANIZATIONS</h2><p>One platform. Every passion. A bigger impact.</p></div>
      <div className="boss-audience-grid">
        {audiences.map(([name,desc,img])=><a href={name==="Sports Teams"?"/sports-teams":"/organizations"} className="boss-audience-card" key={name}>
          <img src={img} alt={name}/>
          <div><b>{name}</b><p>{desc}</p></div>
        </a>)}
      </div>
    </section>

    <section className="boss-bucks-home">
      <div className="boss-phone-mock">
        <div className="boss-phone-notch"/>
        <div className="boss-app-head">BOSS BUCKS <span>DISCOUNTS</span></div>
        <div className="boss-deal-feature"><small>FEATURED DEAL</small><strong>$5 OFF</strong><b>ANY PURCHASE</b><span>UNLIMITED USE</span></div>
        <div className="boss-mini-deals"><div>$1 OFF</div><div>$2 OFF</div><div>$2 OFF</div></div>
        <div className="boss-mini-nav"><span>Home</span><span>Deals</span><span>Near Me</span><span>Favorites</span><span>Account</span></div>
      </div>
      <div className="boss-bucks-copy">
        <div className="boss-kicker">BOSS BUCKS DIGITAL DISCOUNTS</div>
        <h2>BOSS BUCKS<br/><span>DIGITAL DISCOUNTS</span></h2>
        <h3>Raise, Save, Support Expenses Like a Boss.</h3>
        <p>Boss Bucks is our digital discount card that helps people support your team or organization while enjoying valuable savings all year long.</p>
        <ul>
          <li>Save at local restaurants, entertainment, travel and more</li>
          <li>Help families offset team-related costs</li>
          <li>Support local businesses</li>
          <li>Give supporters a real reason to stay connected</li>
        </ul>
        <div className="boss-trial-card">
          <b>Want a no-selling fundraising option?</b>
          <p>Give away free 30–90 day digital trials. Supporters can donate immediately, and donations of $25 or more can include a free digital card as a thank-you. Smaller donors can give now and purchase later, creating two ways for your organization to raise funds.</p>
        </div>
        <a className="boss-orange-button" href="/boss-bucks">Learn More →</a>
      </div>
      <div className="boss-bucks-photo">
        <img src={player} alt="Young athlete holding a phone"/>
        <div className="boss-handwritten small">Real Savings.<br/>Real Support.<br/>Real Impact.</div>
      </div>
      <div className="boss-category-row"><span>Restaurants</span><span>Travel</span><span>Shopping</span><span>Fuel & Auto</span><span>Haircuts</span><span>Entertainment</span></div>
    </section>

    <section className="boss-money-home">
      <div className="boss-money-copy">
        <h2>THE DIGITAL<br/><span>MONEY BOARD</span></h2>
        <h3>Small Amounts. Big Impact.</h3>
        <p>We have all seen the paper calendar or whiteboard fundraiser where people choose a dollar amount. The Boss Digital Money Board turns that familiar idea into a one-of-a-kind, state-of-the-art digital fundraising experience.</p>
        <p>Set your goal, starting amount and increment. The system creates your custom board, tracks every contribution and connects each donation to the right player, individual or family.</p>
        <a className="boss-orange-button" href="/money-board">Learn More →</a>
      </div>
      <div className="boss-money-device">
        <div className="boss-money-device-top"><small>THE</small><b>MONEY BOARD</b><span>SMALL AMOUNTS. BIG IMPACT.</span></div>
        <div className="boss-money-progress"><strong>$8,425</strong><span>56% FUNDED</span><strong>$15,000</strong></div>
        <div className="boss-money-modes"><b>DONATE</b><b>SPIN</b></div>
        <div className="boss-money-tiles">{["$5","$10","$15","$20","$25","$30","$40","$50","$75"].map((v,i)=><span className={i===1||i===4?"paid":""} key={v}>{v}<small>{i===1||i===4?"FUNDED":"AVAILABLE"}</small></span>)}</div>
      </div>
      <div className="boss-money-side">
        <img src={player} alt="Athlete celebrating"/>
        <ul>
          <li>Custom digital money board for your team</li>
          <li>Set your goal, start amount & increments</li>
          <li>Leaderboard & family/fan support</li>
          <li>Optional free Boss Bucks thank-you cards</li>
          <li>Track progress in real time</li>
        </ul>
        <div className="boss-money-note">FUNDRAISING<br/>MADE SIMPLE.<br/>MORE SUPPORT.<br/>BIGGER IMPACT.</div>
      </div>
    </section>

    <section className="boss-engage-home">
      <div className="boss-engage-title"><h2>BOSS <span>ENGAGE</span></h2><p>ALL-IN-ONE TEAM & FAMILY HUB</p><a href="/engage">Learn More →</a></div>
      <div className="boss-engage-tools">
        {["Registration & Rosters","Payments & Fundraising","Schedules & Calendars","Chats & Messaging","Livestream & Media","Playbooks & Resources","Team & Fan Gear","Courses & Training"].map((x,i)=><div key={x}><i>{["●","▣","▦","●","▶","▤","◆","◆"][i]}</i><span>{x}</span></div>)}
      </div>
    </section>

    <section className="boss-passions">
      <div className="boss-passions-title">SUPPORTING <span>EVERY PASSION</span></div>
      <div className="boss-passions-row">{passions.map((x,i)=><div key={x}><img src={[football,sportsHero,youth,player,football,youth,player,school,community][i]} alt={x}/><b>{x}</b></div>)}</div>
      <div className="boss-passions-note">DIFFERENT<br/>PASSIONS.<br/>SAME MISSION.</div>
    </section>

    <section className="boss-merchants-home">
      <div><h2>LOCAL BUSINESSES MAKE A BIGGER IMPACT</h2><p>Partner with Boss Bucks and reach families, fans and your community while supporting a great cause.</p><a href="/merchant-partner">Become a Partner →</a></div>
      <div className="boss-merchant-cats"><span>Restaurants</span><span>Entertainment</span><span>Travel & Hotels</span><span>Fuel & Auto</span><span>Haircuts & Salons</span><span>Local Services</span></div>
    </section>

    <footer className="boss-home-footer">
      <div className="boss-home-brand footer"><span className="boss-mark">B</span><span><b>THE BOSS</b><small>PEOPLE. PURPOSE. POSSIBILITIES.</small></span></div>
      <nav><a href="/">Home</a><a href="/fundraising">Fundraising</a><a href="/boss-bucks">Boss Bucks</a><a href="/engage">Boss Engage</a><a href="/organizations">Organizations</a><a href="/how-it-works">Resources</a><a href="/contact">Contact</a></nav>
      <div className="boss-footer-impact">Let’s Make a <b>Bigger Impact Together.</b></div>
      <div className="boss-footer-bottom">© 2026 The Boss. All rights reserved. <span>Stronger Communities. Brighter Possibilities.</span></div>
    </footer>
  </main>
}
