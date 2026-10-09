import Link from "next/link";

export function Brand({ href = "/" }: { href?: string }) {
  return (
    <Link className="brand" href={href} aria-label="The Boss home">
      THE BOSS
    </Link>
  );
}
