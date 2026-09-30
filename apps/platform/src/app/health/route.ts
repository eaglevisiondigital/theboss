import { NextResponse } from "next/server";
import { getHealthStatus } from "@/lib/health";
import { preventAuthCaching } from "@/lib/supabase/response";

export const dynamic = "force-dynamic";

export async function GET() {
  // Configuration readiness only, no database or Auth request and no values exposed.
  const health = getHealthStatus({
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    NODE_ENV: process.env.NODE_ENV,
  });
  return preventAuthCaching(NextResponse.json({ status: health.status }, { status: health.httpStatus }));
}
