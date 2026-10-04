// Use the owner-supplied PNG byte-for-byte. Never redraw, crop, or filter this artwork.
export default function BossPlusIcon({ className }: { className?: string }) {
  return <img src="/brand/boss-plus-approved.png" alt="Boss Plus" width={1254} height={1254} className={className} style={{objectFit:"contain",height:"auto",flexShrink:0,borderRadius:0}} />;
}
