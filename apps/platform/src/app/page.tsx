import Link from "next/link";
import { PublicHeader } from "@/components/public-header";

export default function PlatformLandingPage() {
  return (
    <div className="public-page">
      <PublicHeader />
      <main id="main-content" className="landing-main container">
        <section className="landing-hero" aria-labelledby="landing-title">
          <div className="hero-copy">
            <p className="eyebrow"><span className="eyebrow-mark" aria-hidden="true" />The Boss platform</p>
            <h1 id="landing-title">Your Boss<br />connection.</h1>
            <p className="hero-description">
              One account for your place in the Boss ecosystem.
            </p>
            <Link className="button button-primary" href="/login">
              Sign in to The Boss
              <span aria-hidden="true">↗</span>
            </Link>
          </div>
          <div className="hero-art" aria-hidden="true">
            <span className="art-caption">One connected ecosystem</span>
            <div className="art-circle" />
            <p className="art-words">ONE<br />BOSS<br />ACCOUNT.</p>
            <span className="art-footnote">It starts with you.</span>
          </div>
        </section>
        <div className="landing-note">
          <p className="eyebrow">A connected foundation</p>
          <p>Your Boss account is the starting point for what comes next.</p>
        </div>
      </main>
      <footer className="public-footer container">
        <span>The Boss</span>
        <span>One account. Many possibilities.</span>
      </footer>
    </div>
  );
}
