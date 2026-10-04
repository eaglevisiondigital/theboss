"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSearchParams } from "next/navigation";
import type { AdminNavigation } from "@/lib/admin/contracts";

export function AppNavigation({ navigation = [], calendarAvailable = false, registrationAvailable = false, communicationsAvailable = false, notificationsAvailable = false, attendanceAvailable = false, volunteersAvailable = false, gamesAvailable = false }: { navigation?: AdminNavigation[]; calendarAvailable?: boolean; registrationAvailable?: boolean; communicationsAvailable?: boolean; notificationsAvailable?: boolean; attendanceAvailable?: boolean; volunteersAvailable?: boolean; gamesAvailable?: boolean }) {
  const pathname = usePathname();
  const organization = useSearchParams().get("org");
  const context = organization && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(organization) ? `?org=${organization}` : "";
  const labels: Record<AdminNavigation, string> = { organizations: "Organizations", people: "People", families: "Families", teams: "Teams", access: "Access", audit: "Audit" };
  const destinations = [
    { href: "/app", label: "Home" },
    ...navigation.map((view) => ({ href: `/app/${view}`, label: labels[view] })),
    ...((attendanceAvailable || volunteersAvailable || gamesAvailable) && !navigation.includes("families") ? [{ href: "/app/families", label: "Family Hub" }] : []),
    ...(calendarAvailable ? [{ href: "/app/calendar", label: "Calendar" }] : []),
    ...(gamesAvailable ? [{ href: "/app/games", label: "Game Center" }] : []),
    ...(registrationAvailable ? [{ href: "/app/registrations", label: "Registrations" }] : []),
    ...(attendanceAvailable ? [{ href: "/app/attendance", label: "Attendance" }] : []),
    ...(volunteersAvailable ? [{ href: "/app/volunteers", label: "Volunteers" }] : []),
    ...(communicationsAvailable ? [{ href: "/app/messages", label: "Messages" }, { href: "/app/announcements", label: "Announcements" }] : []),
    ...(notificationsAvailable ? [{ href: "/app/notifications", label: "Notifications" }] : []),
    { href: "/app/account", label: "Account" },
  ];

  return (
    <nav className="app-navigation" aria-label="Main navigation">
      {destinations.map(({ href, label }) => (
        <Link
          key={href}
          href={`${href}${href === "/app/account" ? "" : context}`}
          className="navigation-link"
          aria-current={pathname === href ? "page" : undefined}
        >
          {label}
        </Link>
      ))}
    </nav>
  );
}
