import { defineConfig, globalIgnores } from "eslint/config";
import javascript from "@eslint/js";
import typescript from "typescript-eslint";
import next from "@next/eslint-plugin-next";

export default defineConfig([
  javascript.configs.recommended,
  ...typescript.configs.recommended,
  {
    files: ["src/**/*.ts", "src/**/*.tsx"],
    plugins: { "@next/next": next },
    rules: {
      ...next.configs.recommended.rules,
      ...next.configs["core-web-vitals"].rules,
    },
  },
  globalIgnores([".next/**", ".netlify/**", "node_modules/**", "next-env.d.ts"]),
]);
