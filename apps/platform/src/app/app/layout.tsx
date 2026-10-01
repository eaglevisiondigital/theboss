import { Brand } from "@/components/brand";
import { AppNavigation } from "@/components/app-navigation";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { Suspense } from "react";

export default async function AppLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  await requireSession();
  const data = await loadAdminView("home");

  return (
    <div className="authenticated-page admin-shell">
      <header className="app-header">
        <div className="app-header-inner container">
          <Brand href="/app" />
          <span className="workspace-label">Your Boss workspace</span>
          <form action="/auth/logout" method="post" className="logout-form">
            <button type="submit" className="button button-small button-outline">Sign out</button>
          </form>
        </div>
        <div className="container"><Suspense fallback={<nav className="app-navigation" aria-label="Main navigation" />}><AppNavigation navigation={data.navigation} /></Suspense></div>
      </header>
      <main id="main-content" className="app-main container">{children}</main>
      <footer className="app-footer container"><span>The Boss platform</span><span>Operational core</span></footer>
    </div>
  );
}
