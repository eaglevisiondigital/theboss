import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { loadCommunications } from "@/lib/communications/data";
import { emptyCommunications } from "@/lib/communications/contracts";
import { parseCommunicationQuery } from "@/lib/communications/input";
import { CommunicationsConsole } from "@/components/communications/console";
export const metadata: Metadata = { title: "Messages" };
export const dynamic = "force-dynamic";
export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  await requireSession("/app/messages"); const query = parseCommunicationQuery(await searchParams, "messages");
  const data = query ? await loadCommunications(query) : { ...emptyCommunications, unavailable: true };
  return <CommunicationsConsole data={data} query={query ?? { view: "messages" }} />;
}
