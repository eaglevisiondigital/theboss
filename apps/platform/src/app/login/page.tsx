import type { Metadata } from "next";
import { PublicHeader } from "@/components/public-header";
import { getSafeNextPath } from "@/lib/auth/redirects";

export const metadata: Metadata = { title: "Sign in" };

type LoginSearchParams = Record<string, string | string[] | undefined>;

const errorMessages = new Map([
  ["invalid", "We couldn’t sign you in. Check your details and try again."],
  ["unavailable", "Sign-in is temporarily unavailable. Please try again later."],
  ["expired", "Your session has ended. Please sign in again."],
]);

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<LoginSearchParams>;
}) {
  const params = await searchParams;
  const nextPath = getSafeNextPath(params.next);
  const errorCode = typeof params.error === "string" ? params.error : undefined;
  const errorMessage = errorCode ? errorMessages.get(errorCode) : undefined;

  return (
    <div className="public-page">
      <PublicHeader showSignIn={false} />
      <main id="main-content" className="login-main container">
        <div className="login-shell">
          <section className="login-intro" aria-labelledby="login-intro-title">
            <p className="eyebrow"><span className="eyebrow-mark" aria-hidden="true" />One Boss account</p>
            <h1 id="login-intro-title">Your place <br />in The Boss.</h1>
            <p>One account. Many possibilities.</p>
            <div className="login-accent" aria-hidden="true" />
          </section>
          <section className="login-form-panel" aria-labelledby="login-title">
            <p className="eyebrow muted">Welcome back</p>
            <h2 id="login-title">Sign in</h2>
            <p className="form-description">Enter your Boss account details to continue.</p>
            {errorMessage && (
              <p className="form-notice" role="alert" id="login-error">
                {errorMessage}
              </p>
            )}
            <form
              action="/auth/login"
              method="post"
              className="login-form"
              aria-describedby={errorMessage ? "login-error" : undefined}
            >
              <input type="hidden" name="next" value={nextPath} />
              <div className="form-field">
                <label htmlFor="email">Email address</label>
                <input
                  id="email"
                  name="email"
                  type="email"
                  autoComplete="username"
                  autoCapitalize="none"
                  spellCheck={false}
                  inputMode="email"
                  maxLength={254}
                  required
                />
              </div>
              <div className="form-field">
                <label htmlFor="password">Password</label>
                <input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  required
                />
              </div>
              <button className="button button-primary" type="submit">
                Sign in
                <span aria-hidden="true">↗</span>
              </button>
            </form>
          </section>
        </div>
      </main>
      <footer className="public-footer container">
        <span>The Boss</span>
        <span>Your connections start here.</span>
      </footer>
    </div>
  );
}
