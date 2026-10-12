import Link from "next/link";

export default function NotFoundPage() {
  return (
    <main id="main-content" className="recovery-main container">
      <p className="eyebrow muted">The Boss · 404</p>
      <h1>Page not found.</h1>
      <p>The page you’re looking for isn’t available.</p>
      <div className="recovery-actions">
        <Link className="button button-primary" href="/">Go to home</Link>
        <Link className="button button-outline" href="/login">Sign in</Link>
      </div>
    </main>
  );
}
