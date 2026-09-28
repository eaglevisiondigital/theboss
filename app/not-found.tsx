import Link from "next/link";
import SiteHeader from "@/components/SiteHeader";
import SiteFooter from "@/components/SiteFooter";

export default function NotFound(){
  return <main style={{minHeight:"100vh",background:"#0b0b0d",color:"#fff"}}>
    <SiteHeader/>
    <section style={{minHeight:"68vh",display:"grid",placeItems:"center",padding:"70px 24px",textAlign:"center"}}>
      <div>
        <div style={{fontSize:11,letterSpacing:".2em",fontWeight:900,color:"#ff6b13"}}>BOSS PLUS</div>
        <h1 style={{fontSize:"clamp(56px,9vw,120px)",letterSpacing:"-.07em",lineHeight:.9,margin:"18px 0"}}>Wrong turn.<br/>Still in the right ecosystem.</h1>
        <p style={{maxWidth:620,margin:"0 auto 28px",color:"#aaa",fontSize:18,lineHeight:1.6}}>The page you were looking for is not available, but the Boss ecosystem is one click away.</p>
        <Link href="/" style={{display:"inline-block",background:"linear-gradient(135deg,#ff7a00,#ff4f00)",padding:"15px 22px",borderRadius:999,fontWeight:900}}>Back to BOSS PLUS →</Link>
      </div>
    </section>
    <SiteFooter/>
  </main>
}
