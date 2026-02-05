import { defineConfig } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

const baseURL = process.env.PW_BASE_URL ?? "http://127.0.0.1:5173";
const workspace = process.env.SMITHERS_WORKSPACE ?? process.cwd();
const rootDir = process.cwd();
const artifactsDir = join(rootDir, "test-results");
mkdirSync(artifactsDir, { recursive: true });
const configuredDbPath = (process.env.SMITHERS_DB_PATH ?? "").trim();
const dbPath = configuredDbPath || join(artifactsDir, `smithers-e2e-${Date.now()}.db`);

export default defineConfig({
  testDir: "tests/e2e",
  timeout: 60_000,
  expect: {
    timeout: 15_000,
  },
  fullyParallel: false,
  workers: 1,
  use: {
    baseURL,
    trace: "retain-on-failure",
    video: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  webServer: {
    command: "bun run web:dev",
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    env: {
      ...process.env,
      SMITHERS_WORKSPACE: workspace,
      SMITHERS_DB_PATH: dbPath,
      OPENAI_API_KEY: "",
      ANTHROPIC_API_KEY: "",
    },
  },
});
