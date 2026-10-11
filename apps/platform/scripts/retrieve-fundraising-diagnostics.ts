// Local operator tool for an already protected, sanitized function-log export.
// No network, browser storage, auth lookup, or production mutation.
import { lstatSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { parseFundraisingDiagnostic, validFundraisingCorrelation } from "../src/lib/fundraising/diagnostics";
const args = process.argv.slice(2);
if (args.length !== 6 && args.length !== 8 || args[0] !== "--input" || args[2] !== "--correlation" || args[4] !== "--output" || args.length === 8 && args[6] !== "--since") throw Error("Use --input protected-export --correlation diagnostic-id --output new-private-export [--since UTC]");
const input = resolve(args[1]), output = resolve(args[5]), id = args[3], since = args[7];
if (!validFundraisingCorrelation(id) || input === output || since !== undefined && (!/^\d{4}-\d{2}-\d{2}T.*Z$/.test(since) || !Number.isFinite(Date.parse(since)))) throw Error("Invalid diagnostic retrieval parameters");
const stat = lstatSync(input);
if (!stat.isFile() || stat.isSymbolicLink() || stat.size > 5_000_000 || (stat.mode & 0o077) !== 0 || stat.uid !== process.getuid?.()) throw Error("Owner-only regular log export required (maximum 5 MB)");
const records = readFileSync(input, "utf8").split("\n").map(parseFundraisingDiagnostic).filter(r => r && (r.correlation_id === id || r.parent_correlation_id === id) && (!since || Date.parse(r.timestamp) >= Date.parse(since))).slice(0, 1000);
if (!records.length) throw Error("No matching sanitized diagnostic records");
writeFileSync(output, JSON.stringify({ schema: "boss.fundraising.operator-export.v1", correlation_id: id, records }, null, 2) + "\n", { mode: 0o600, flag: "wx" });
console.info(JSON.stringify({ retrieved: records.length, bounded: true, private_export: true }));
