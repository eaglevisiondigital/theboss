import Link from "next/link";
import ApprovedHeader from "@/components/ApprovedHeader";
import ApprovedFooter from "@/components/ApprovedFooter";
import home from "@/app/approvedHome.module.css";
import s from "./merchants.module.css";

export const metadata = { title: "Merchants | Get Listed Free on Boss Bucks Digital", description: "Give families a reason to choose your business. Explore a free Boss Bucks Digital listing, local and nationwide discovery, meaningful offers and community fundraising." };
const discovery = [
  ["01", "Be found nearby", "Location-based discovery is designed to help members find participating businesses and relevant offers near home, work or wherever the day takes them."],
  ["02", "Welcome people on the road", "Reach eligible members exploring beyond their hometown, including families traveling for games, tournaments and other activities. Offer access follows membership coverage and your participating locations."],
  ["03", "Stay relevant with geofencing", "Planned, permission-based geofencing can surface relevant offers when members are near a participating location, subject to their location and notification preferences."],
  ["04", "Turn discovery into directions", "The planned listing experience connects your business address with map directions, making it easier for customers to get from finding your offer to finding your front door."],
  ["05", "Connect to your website", "Help customers learn more, browse your menu, book a service or follow a link to your own online ordering experience where available."],
  ["06", "Give them a reason to return", "A useful, clearly explained offer gives members a reason to choose you again. Set the participating locations, eligible purchases and redemption frequency that fit your business."],
];
const steps = [
  ["01", "Start the conversation", "Tell us about your business, where you operate and the offer you have in mind. Request a free Boss Bucks Digital listing."],
  ["02", "Shape your offer", "We’ll follow up to discuss your business information, participating locations, offer details and redemption rules."],
  ["03", "Get ready to welcome members", "After review and approval, we’ll coordinate listing availability and help you prepare your team to recognize and honor the offer."],
];
export default function Page() {
  return <div className={home.home}><a className={home.skipLink} href="#main-content">Skip to content</a><ApprovedHeader />
    <main id="main-content" className={s.page}>
      <section className={s.hero}>
        <div className={s.heroCopy}><p className={s.eyebrow}>BOSS BUCKS DIGITAL · FOR MERCHANTS</p><h1>More reasons<br/>to choose you.<br/><em>More ways to<br/>support them.</em></h1><p>Put a meaningful offer in front of families and supporters. Help make community fundraising more valuable while giving people a reason to visit your business.</p><div className={s.actions}><Link className={s.primary} href="/merchant-partner">Get Listed Free <span aria-hidden="true">→</span></Link><a className={s.secondary} href="#merchant-benefits">See How It Works</a></div><p className={s.heroNote}>Free business listing on Boss Bucks Digital. Offer review and approval apply.</p></div>
        <figure className={s.heroVisual}><img src="/images/approved/account-discount-bbq-exact.webp" width="4608" height="3072" alt="Illustrative scene of a customer presenting a Boss Bucks barbecue discount at checkout" fetchPriority="high"/><figcaption><span>LOCAL DEALS. REAL CONNECTIONS.</span>A better reason to stop in.</figcaption></figure>
      </section>
      <section id="merchant-benefits" className={s.impact}>
        <div><p className={s.eyebrow}>GOOD FOR BUSINESS. MEANINGFUL FOR FAMILIES.</p><h2>Your offer can be part<br/>of a <em>bigger story.</em></h2></div><div><p>Teams and organizations can use Boss Bucks memberships as part of an approved fundraiser. The savings you offer help make that membership useful long after the initial show of support.</p><p>That value can help organizations raise support for young people and the activities that matter to them, from team participation and camps to equipment and approved travel.</p><p className={s.note}>Your contribution is the offer you agree to honor. Customer purchases at your business do not automatically generate a donation or add money to a family’s Boss Bucks balance.</p></div>
      </section>
      <section className={s.discovery}>
        <div className={s.sectionHeading}><div><p className={s.eyebrow}>FROM DISCOVERY TO YOUR DOOR</p><h2>Local customers.<br/><em>A wider welcome.</em></h2></div><p>Boss Bucks is being built to connect valuable offers with eligible members locally and nationwide. Here’s the merchant experience we’re working toward.</p></div>
        <div className={s.discoveryGrid}>{discovery.map(([number,title,copy])=><article key={number}><span className={s.number}>{number}</span><h3>{title}</h3><p>{copy}</p></article>)}</div><p className={s.note}>Discovery, geofencing, maps and listing features are planned platform capabilities. Availability varies by launch stage, location and program. Listing does not guarantee traffic, sales or placement.</p>
      </section>
      <section className={s.offer}>
        <div><p className={s.eyebrow}>MAKE THE OFFER WORTH THE VISIT</p><h2>A great offer<br/>is an <em>invitation.</em></h2><p>The quality of your offer matters. Give members a clear, compelling reason to choose your business, with terms your team can explain and honor confidently.</p><Link className={s.primary} href="/merchant-partner">Let’s Talk About Your Offer <span aria-hidden="true">→</span></Link></div>
        <div className={s.offerPanel}><h3>Value that fits your business.</h3><div className={s.offerTypes}><span>Percentage off</span><span>Dollar savings</span><span>Buy one, get one</span><span>Complimentary item</span><span>Member pricing</span></div><ul><li>Clearly state what the customer receives.</li><li>Identify eligible purchases and participating locations.</li><li>Explain exclusions, timing and how often it can be used.</li><li>Make redemption simple for customers and staff.</li></ul><p className={s.note}>Proposed offers are reviewed for fit and clarity. We’ll discuss the options available for your business.</p></div>
      </section>
      <section className={s.join}>
        <div className={s.sectionHeading}><div><p className={s.eyebrow}>ONE LOCATION OR MANY</p><h2>A free listing.<br/><em>A simple next step.</em></h2></div><p>Restaurants, shops, services and family experiences can all bring something valuable to the network. Tell us about your local business, regional group or nationwide footprint.</p></div>
        <div className={s.steps}>{steps.map(([number,title,copy])=><article key={number}><span className={s.number}>{number}</span><h3>{title}</h3><p>{copy}</p></article>)}</div>
        <div className={s.future}><span>COMING LATER</span><div><h3>Your merchant back office.</h3><p>Planned self-service tools will connect registration, business and location setup, and discount submission in one place. For now, start with the merchant inquiry form and our team will guide the next step.</p></div></div>
      </section>
      <section className={s.closing}><p className={s.eyebrow}>BE PART OF SOMETHING BIGGER</p><h2>Welcome more possibilities.<br/><em>Partner like a Boss.</em></h2><p>Let’s talk about your business, your community and a free listing on Boss Bucks Digital.</p><div className={s.actions}><Link className={s.primary} href="/merchant-partner">Get Listed Free <span aria-hidden="true">→</span></Link><Link className={s.secondary} href="/request-information">I Have a Question</Link></div><p className={s.heroNote}>An inquiry starts the conversation. It does not automatically publish a listing.</p></section>
    </main><ApprovedFooter />
  </div>;
}
