import { Brand } from "@/components/brand";
import { AppNavigation } from "@/components/app-navigation";
import { requireSession } from "@/lib/auth/session";

export default async function AppLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  await requireSession();

  return (
    <div className="authenticated-page">
      <header className="app-header">
        <div className="app-header-inner container">
          <Brand href="/app" />
          <AppNavigation />
          <form action="/auth/logout" method="post" className="logout-form">
            <button type="submit" className="button button-small button-outline">Sign out</button>
          </form>
        </div>
      </header>
      <main id="main-content" className="app-main container">{children}</main>
      <footer className="app-footer container">The Boss platform</footer>
    </div>
  );
}
