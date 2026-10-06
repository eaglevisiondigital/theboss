import { Brand } from "@/components/brand";
import { AppNavigation } from "@/components/app-navigation";
import { requireSession } from "@/lib/auth/session";
import { loadAdminView } from "@/lib/admin/data";
import { Suspense } from "react";
import { registrationNavigationAvailable } from "@/lib/registration/data";
import { loadNotifications } from "@/lib/notifications/data";
import { communicationsNavigationAvailable } from "@/lib/communications/data";
import { NotificationDrawer } from "@/components/communications/notification-drawer";
import { calendarNavigationAvailable } from "@/lib/calendar/data";
import { attendanceNavigationAvailable } from "@/lib/attendance/data";
import { volunteersNavigationAvailable } from "@/lib/volunteers/data";
import { rankingsNavigationAvailable } from "@/lib/rankings/data";
import { gamesNavigationAvailable } from "@/lib/games/data";
import { athleteProfilesNavigationAvailable } from "@/lib/athlete-profiles/data";

export default async function AppLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  await requireSession();
  const [data, calendarAvailable, registrationAvailable, communicationsAvailable, notifications, attendanceAvailable, volunteersAvailable, gamesAvailable, rankingsAvailable, athleteProfilesAvailable] = await Promise.all([loadAdminView("home"), calendarNavigationAvailable(), registrationNavigationAvailable(), communicationsNavigationAvailable(), loadNotifications({ view: "summary", limit: 5 }), attendanceNavigationAvailable(), volunteersNavigationAvailable(), gamesNavigationAvailable(), rankingsNavigationAvailable(), athleteProfilesNavigationAvailable()]);

  return (
    <div className="authenticated-page admin-shell">
      <header className="app-header">
        <div className="app-header-inner container">
          <Brand href="/app" />
          <span className="workspace-label">Your Boss workspace</span>
          <NotificationDrawer data={notifications} />
          <form action="/auth/logout" method="post" className="logout-form">
            <button type="submit" className="button button-small button-outline">Sign out</button>
          </form>
        </div>
        <div className="container"><Suspense fallback={<nav className="app-navigation" aria-label="Main navigation" />}><AppNavigation navigation={data.navigation} calendarAvailable={calendarAvailable} registrationAvailable={registrationAvailable} communicationsAvailable={communicationsAvailable} notificationsAvailable={!notifications.unavailable && notifications.availability.in_app} attendanceAvailable={attendanceAvailable} volunteersAvailable={volunteersAvailable} gamesAvailable={gamesAvailable} rankingsAvailable={rankingsAvailable} athleteProfilesAvailable={athleteProfilesAvailable} /></Suspense></div>
      </header>
      <main id="main-content" className="app-main container">{children}</main>
      <footer className="app-footer container"><span>The Boss platform</span><span>Operational core</span></footer>
    </div>
  );
}
