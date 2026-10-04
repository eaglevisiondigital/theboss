// The viewBox displays the selected approved artwork crop.
export default function ReferencePhoto({crop, alt, className, preserveAspectRatio, source = "/design/approved-desktop.png"}: {crop: string; alt?: string; className?: string; preserveAspectRatio?: string; source?: string}) {
  return <svg viewBox={crop} preserveAspectRatio={preserveAspectRatio} className={className} role={alt ? "img" : undefined} aria-label={alt} aria-hidden={alt ? undefined : true} focusable="false">
    <image href={source} width="793" height="1983"/>
  </svg>;
}
