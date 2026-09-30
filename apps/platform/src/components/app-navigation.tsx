"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const destinations = [
  { href: "/app", label: "Home" },
  { href: "/app/account", label: "Account" },
];

export function AppNavigation() {
  const pathname = usePathname();

  return (
    <nav className="app-navigation" aria-label="Main navigation">
      {destinations.map(({ href, label }) => (
        <Link
          key={href}
          href={href}
          className="navigation-link"
          aria-current={pathname === href ? "page" : undefined}
        >
          {label}
        </Link>
      ))}
    </nav>
  );
}
