import { loadPublicFundraising } from "@/lib/fundraising/data";
import { getServerEnvironment } from "@/lib/env/server";
import { sharePath } from "@/lib/fundraising/contracts";
import { qrSvg } from "@/lib/fundraising/qr-svg";
export const dynamic = "force-dynamic";
export async function GET(_request: Request, { params }: { params: Promise<{ path: string }> }) { const { path } = await params; if (!sharePath(path) || !await loadPublicFundraising(path)) return new Response("Fundraiser unavailable", { status: 404, headers: { "Cache-Control": "private, no-store" } }); const url = new URL(`/fundraise/${path}?source=qr`, getServerEnvironment().platformOrigin); return new Response(await qrSvg(url.href), { headers: { "Content-Type": "image/svg+xml", "Content-Disposition": 'inline; filename="boss-fundraiser.svg"', "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff", "Content-Security-Policy": "default-src 'none'; style-src 'none'; sandbox" } }); }
