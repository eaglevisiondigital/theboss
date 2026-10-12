import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { RecruitingShowcaseView } from "@/components/athlete-profiles/recruiting-showcase";
import { loadRecruitingShowcase } from "@/lib/athlete-profiles/data";
export const dynamic = "force-dynamic"; export const revalidate = 0;
export const metadata: Metadata = { title: "Private recruiting showcase", robots: { index: false, follow: false, noarchive: true, noimageindex: true } };
export default async function RecruitingPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params, data = await loadRecruitingShowcase(token);
  if (!data.available) notFound();
  return <RecruitingShowcaseView data={data} />;
}
