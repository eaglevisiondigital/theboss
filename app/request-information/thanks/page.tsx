import Link from 'next/link';
import ApprovedHeader from '@/components/ApprovedHeader';
import ApprovedFooter from '@/components/ApprovedFooter';
import home from '@/app/approvedHome.module.css';
export const metadata = { title: 'Information Request Received' };
export default function Page() {
  return <div className={home.home}><ApprovedHeader /><main style={{padding:'80px 24px',textAlign:'center',minHeight:'65vh',background:'#f5f7f9',color:'#111'}}><h1 style={{fontSize:'clamp(2rem,5vw,3.5rem)',letterSpacing:'-.04em'}}>Thanks for your interest in The Boss.</h1><p style={{maxWidth:650,margin:'24px auto',lineHeight:1.7}}>Your information request has been submitted. Our team will review your selected topics and questions, then follow up.</p><Link href="/" style={{display:'inline-block',padding:'16px 24px',background:'#c53b00',color:'#fff',borderRadius:5}}>Explore The Boss →</Link></main><ApprovedFooter showInformationCTA={false} /></div>;
}
