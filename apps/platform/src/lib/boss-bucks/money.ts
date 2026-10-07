import { currencyDigits } from "../fundraising/contracts";
/** Wallet amounts are integer decimal strings to preserve large ledger totals. */
export function bucksMoney(value: number | string, currency: string) {
 const minor = BigInt(value), digits = currencyDigits(currency), divisor = 10n ** BigInt(digits), absolute = minor < 0n ? -minor : minor, whole = absolute / divisor, remainder = absolute % divisor;
 const format = new Intl.NumberFormat("en-US", { style: "currency", currency });
 return format.formatToParts(minor < 0n ? -(whole || 1n) : whole).map(p => p.type === "integer" && minor < 0n && whole === 0n ? "0" : p.type === "fraction" ? remainder.toString().padStart(digits, "0") : p.value).join("");
}
