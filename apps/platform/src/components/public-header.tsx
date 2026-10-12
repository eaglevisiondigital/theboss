import Link from "next/link";
import { Brand } from "./brand";

export function PublicHeader({ showSignIn = true }: { showSignIn?: boolean }) {
  return (
    <header className="public-header container">
      <Brand />
      {showSignIn ? (
        <Link className="button button-small button-outline" href="/login">
          Sign in
          <span aria-hidden="true">↗</span>
        </Link>
      ) : (
        <span className="header-label">Your Boss account</span>
      )}
    </header>
  );
}
