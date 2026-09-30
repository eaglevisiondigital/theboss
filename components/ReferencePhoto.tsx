// The viewBox displays exact approved artwork without redrawing or modifying it.
export default function ReferencePhoto({crop, alt, className}: {crop: string; alt?: string; className?: string}) {
  return <svg viewBox={crop} className={className} role={alt ? "img" : undefined} aria-label={alt} aria-hidden={alt ? undefined : true} focusable="false">
    <image href="/design/approved-desktop.png" width="793" height="1983"/>
  </svg>;
}
