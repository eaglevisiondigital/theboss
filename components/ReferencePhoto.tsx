// The viewBox displays exact approved artwork without redrawing or modifying it.
export default function ReferencePhoto({crop, alt, className, preserveAspectRatio}: {crop: string; alt?: string; className?: string; preserveAspectRatio?: string}) {
  return <svg viewBox={crop} preserveAspectRatio={preserveAspectRatio} className={className} role={alt ? "img" : undefined} aria-label={alt} aria-hidden={alt ? undefined : true} focusable="false">
    <image href="/design/approved-desktop.png" width="793" height="1983"/>
  </svg>;
}
