import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://theboss.biz";
  const routes = [
    "",
    "/boss-bucks",
    "/boss-bucks-account",
    "/fundraising",
    "/money-board",
    "/engage",
    "/family-hub",
    "/sports-teams",
    "/organizations",
    "/merchants",
    "/how-it-works",
    "/about",
    "/request-information",
    "/fundraising/get-started",
    "/merchant-partner",
    "/sales-rep",
    "/contact",
    "/privacy",
    "/terms"
  ];

  return routes.map((route) => ({
    url: `${base}${route}`,
    lastModified: new Date(),
    changeFrequency: route === "" ? "weekly" : "monthly",
    priority: route === "" ? 1 : 0.8
  }));
}
