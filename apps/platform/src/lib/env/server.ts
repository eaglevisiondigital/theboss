import "server-only";
import { parsePublicEnvironment, parseServerEnvironment } from "./validation";

export function getServerEnvironment() {
  // Server checks can inspect all configured names for accidental public credentials.
  parsePublicEnvironment(process.env);
  return parseServerEnvironment(process.env);
}
