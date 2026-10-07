import { currencyDigits } from "../fundraising/contracts";
/** Parse user currency amounts without floating-point rounding. */
export function bucksAmount(text: string, currency: string): number | null {
 const digits = currencyDigits(currency), match = /^(0|[1-9][0-9]*)(?:\.([0-9]+))?$/.exec(text.trim());
 if (!match || (match[2]?.length ?? 0) > digits) return null;
 const minor = BigInt(match[1]) * 10n ** BigInt(digits) + BigInt((match[2] ?? "").padEnd(digits, "0") || "0");
 return minor > 0n && minor <= 1_000_000_000n ? Number(minor) : null;
}
export function bucksDecimal(value: number | string, currency: string): string {
 const minor = BigInt(value), digits = currencyDigits(currency), divisor = 10n ** BigInt(digits);
 return `${minor / divisor}${digits ? `.${(minor % divisor).toString().padStart(digits, "0")}` : ""}`;
}
/** Wallet amounts are integer decimal strings to preserve large ledger totals. */
export function bucksMoney(value: number | string, currency: string) {
 const minor = BigInt(value), digits = currencyDigits(currency), divisor = 10n ** BigInt(digits), absolute = minor < 0n ? -minor : minor, whole = absolute / divisor, remainder = absolute % divisor;
 const format = new Intl.NumberFormat("en-US", { style: "currency", currency });
 return format.formatToParts(minor < 0n ? -(whole || 1n) : whole).map(p => p.type === "integer" && minor < 0n && whole === 0n ? "0" : p.type === "fraction" ? remainder.toString().padStart(digits, "0") : p.value).join("");
}
