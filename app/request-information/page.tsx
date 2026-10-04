import Link from 'next/link';
import ApprovedHeader from '@/components/ApprovedHeader';
import ApprovedFooter from '@/components/ApprovedFooter';
import home from '@/app/approvedHome.module.css';
import s from '@/app/fundraising/get-started/intake.module.css';
import InformationForm from './InformationForm';

export const metadata = { title: 'Request Information', description: 'Choose what you would like to learn about The Boss, from fundraising and discounts to teams and family accounts.' };

export default function Page() {
  return <div className={home.home}>
    <a className={home.skipLink} href="#main-content">Skip to content</a>
    <ApprovedHeader />
    <main id="main-content" className={s.page}>
      <section style={{background:'#101111',color:'#fff',padding:'48px 24px'}}>
        <div style={{maxWidth:1252,margin:'auto'}}>
          <p style={{color:'#ff641b',fontWeight:800,letterSpacing:'.08em'}}>REQUEST INFORMATION</p>
          <h1 style={{fontSize:'clamp(2.2rem,5vw,4rem)',letterSpacing:'-.04em',lineHeight:1.05,margin:'16px 0'}}>Let’s find your <span style={{color:'#ff5409'}}>Boss possibilities.</span></h1>
          <p style={{maxWidth:700,lineHeight:1.6}}>Have a question or want to learn more? Select the topics that interest you, and our team will help you explore your next step.</p>
          <p style={{lineHeight:1.6}}>Ready to plan a fundraiser? <Link href="/fundraising/get-started" style={{color:'#ffab80',textDecoration:'underline'}}>Start here →</Link></p>
        </div>
      </section>
      <InformationForm />
    </main>
    <ApprovedFooter />
  </div>;
}
