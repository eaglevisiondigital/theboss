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
const offerTypes = [
  ["%", "Percentage off", "A clear saving on eligible purchases."],
  ["$", "Dollar savings", "A set amount off a qualifying visit."],
  ["2", "Buy one, get one", "Give customers another reason to share."],
  ["+", "Complimentary item", "Add something extra to their experience."],
  ["★", "Member pricing", "Make membership feel valuable."],
];
const backOfficeFeatures = [
  ["01", "Digital, physical or both", "Choose whether to offer your discount on Boss Bucks Digital, participating physical fundraising cards, or both. Select the formats that fit your business."],
  ["02", "More offers. More reasons to visit.", "Add additional discounts and special offers so customers have more ways to find value at your business. Keep the details and redemption terms clear for each offer."],
  ["03", "The right offer at each location", "Manage multiple locations and choose which discounts apply at each one. Give individual locations relevant offers while keeping your business information together."],
  ["04", "Turn slow days into opportunities", "Future push-notification tools are planned to help you share timely promotions with opted-in supporters, giving them a reason to stop in on slower days or explore a special offer."],
  ["05", "Put promotions on Boss Bucks", "Submit special offers for discovery on Boss Bucks, with the goal of bringing more attention, visits and revenue opportunities to your participating locations."],
  ["06", "One place to manage the details", "Planned self-service registration, business profiles, location details and offer submission will bring your merchant setup together in one back office."],
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
        <div className={s.offerPanel}>
          <div className={s.offerPanelHeader}><p className={s.eyebrow}>YOUR BUSINESS. YOUR OFFER.</p><h3>Value that fits<br/>your business.</h3><p>Make the next visit worth choosing you.</p></div>
          <div className={s.offerPanelBody}><div className={s.offerTypes}>{offerTypes.map(([symbol,title,copy])=><div className={s.offerType} key={title}><span aria-hidden="true">{symbol}</span><div><h4>{title}</h4><p>{copy}</p></div></div>)}</div>
          <div className={s.offerChecklist}><h4>A great offer is easy to understand.</h4><ul><li>State the saving and eligible purchases.</li><li>Choose participating locations.</li><li>Explain exclusions, timing and usage limits.</li><li>Keep redemption simple for customers and staff.</li></ul></div><p className={s.note}>Proposed offers are reviewed for fit and clarity. We’ll help you explore the options for your business.</p></div>
        </div>
      </section>
      <section className={s.join}>
        <div className={s.sectionHeading}><div><p className={s.eyebrow}>ONE LOCATION OR MANY</p><h2>A free listing.<br/><em>A simple next step.</em></h2></div><p>Restaurants, shops, services and family experiences can all bring something valuable to the network. Tell us about your local business, regional group or nationwide footprint.</p></div>
        <div className={s.steps}>{steps.map(([number,title,copy])=><article key={number}><span className={s.number}>{number}</span><h3>{title}</h3><p>{copy}</p></article>)}</div>
        <div className={s.future}>
          <div className={s.futureHeading}><div><span className={s.futureBadge}>PLANNED MERCHANT TOOLS</span><h3>Your offers. Your locations.<br/><em>Your merchant back office.</em></h3></div><p>More control over how you show up. More ways to give supporters a reason to choose you. Here’s what we’re planning for your merchant workspace.</p></div>
          <div className={s.futureGrid}>{backOfficeFeatures.map(([number,title,copy])=><article key={number}><span className={s.futureNumber}>{number}</span><h4>{title}</h4><p>{copy}</p></article>)}</div>
          <div className={s.futureNext}><div><h4>Start the conversation today.</h4><p>Tell us about your business and the offers you have in mind. Our team will guide your next step while these tools are being developed.</p></div><Link className={s.primary} href="/merchant-partner">Explore a Free Digital Listing <span aria-hidden="true">→</span></Link></div>
          <p className={s.futureNote}>These are planned capabilities, not tools available today. Physical-card participation and offers are subject to program availability and approval. Future notifications will respect supporter opt-in preferences; promotion tools do not guarantee visits or revenue.</p>
        </div>
      </section>
      <section className={s.closing}><p className={s.eyebrow}>BE PART OF SOMETHING BIGGER</p><h2>Welcome more possibilities.<br/><em>Partner like a Boss.</em></h2><p>Let’s talk about your business, your community and a free listing on Boss Bucks Digital.</p><div className={s.actions}><Link className={s.primary} href="/merchant-partner">Get Listed Free <span aria-hidden="true">→</span></Link><Link className={s.secondary} href="/request-information">I Have a Question</Link></div><p className={s.heroNote}>An inquiry starts the conversation. It does not automatically publish a listing.</p></section>
    </main><ApprovedFooter />
  </div>;
}
