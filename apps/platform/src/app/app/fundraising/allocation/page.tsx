import { fundraisingPageTrace } from "@/lib/fundraising/diagnostics-server";
import type { Metadata } from "next";
import { requireSession } from "@/lib/auth/session";
import { allocationQuery } from "@/lib/fundraising-allocation/contracts";
import { loadAllocation } from "@/lib/fundraising-allocation/data";
import { AllocationConsole } from "@/components/fundraising/allocation-console";
export const metadata: Metadata = { title: "Fundraising allocation and source reporting" };
export const dynamic = "force-dynamic";
export default async function AllocationPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
 const trace=await fundraisingPageTrace("/app/fundraising/allocation","src/app/app/fundraising/allocation/page.tsx"); await requireSession("/app/fundraising/allocation");const query = allocationQuery(await searchParams);
 if (!query) return <p role="status">Select a campaign and its exact authorized team or ministry scope.</p>;
 const result = await loadAllocation(query,trace);
 return <><h1>Fundraising allocation and source reporting</h1>{result.data ? <AllocationConsole diagnosticId={trace.correlationId} data={result.data} scope={query} /> : <p role="status">{result.restricted ? "This fundraising scope is restricted." : "Fundraising allocation is currently unavailable."}</p>}</>;
}
