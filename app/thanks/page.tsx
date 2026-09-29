import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";

export const metadata={title:"Thank You"};

export default function Page(){
  return <main style={{minHeight:"100vh",background:"#0b0b0d",color:"#fff"}}>
    <SiteHeader/>
    <section style={{minHeight:"68vh",display:"grid",placeItems:"center",padding:"70px 24px",textAlign:"center"}}>
      <div>
        <div style={{color:"#ff6410",fontWeight:900,letterSpacing:".2em",fontSize:11}}>BOSS PLUS</div>
        <h1 style={{fontSize:"clamp(48px,8vw,90px)",letterSpacing:"-.06em",margin:"18px 0"}}>We got it.</h1>
        <p style={{color:"#aaa",fontSize:18,maxWidth:600,lineHeight:1.6,margin:"0 auto"}}>Thanks for reaching out. Your information has been submitted and can now be routed to the right Boss conversation.</p>
        <a href="/" style={{display:"inline-block",marginTop:24,background:"linear-gradient(135deg,#ff7a00,#ff4f00)",padding:"14px 20px",borderRadius:999,fontWeight:900}}>Back to BOSS PLUS →</a>
      </div>
    </section>
    <SiteFooter/>
  </main>
}
