import Image from "next/image";
import { sharePath } from "@/lib/fundraising/contracts";
export function FundraisingQr({ path }: { path: string }) { if (!sharePath(path)) return null; return <div className="fundraising-qr"><Image unoptimized src={`/fundraise/${path}/qr`} alt="QR code for this canonical fundraising link" width={180} height={180} /><a href={`/fundraise/${path}/qr`} download="boss-fundraiser.svg">Download QR</a></div>; }
