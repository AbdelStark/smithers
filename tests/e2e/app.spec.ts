import { test, expect } from "@playwright/test";
import path from "node:path";
import {
  waitForAppReady,
  ensureWorkspace,
  workspaceRoot,
  helloWorkflowPath,
  runWorkflowViaDialog,
  waitForRunStatus,
  openSettingsDialog,
} from "./utils";

test.describe("Smithers Web App", () => {
  test("boots and shows main chrome", async ({ page }) => {
    await waitForAppReady(page);
    await expect(page.locator("#workspace-select")).toBeVisible();
    await expect(page.locator("#session-select")).toBeVisible();
    await expect(page.locator("#new-session")).toBeVisible();
    await expect(page.locator("#run-workflow")).toBeVisible();
  });

  test("creates a new chat session", async ({ page }) => {
    await waitForAppReady(page);
    const select = page.locator("#session-select");
    const initialCount = await select.locator("option").count();

    await page.click("#new-session");
    await expect(select.locator("option")).toHaveCount(initialCount + 1);
  });

  test("opens workspace and lists workflows", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await page.click("#tab-workflows");
    await expect(page.locator(".workflow-row__title", { hasText: "hello" })).toBeVisible();
  });

  test("workflow list run button opens dialog", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await page.click("#tab-workflows");
    await page.locator(".workflow-row", { hasText: "hello" }).locator("button", { hasText: "Run" }).click();
    await expect(page.locator("#workflow-select")).toBeVisible();
    await expect(page.locator("#workflow-select")).toHaveValue(helloWorkflowPath);
    await page.keyboard.press("Escape");
  });

  test("toggles the workflow sidebar", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await page.click("#toggle-sidebar");
    await expect(page.locator("#sidebar")).toHaveClass(/sidebar--closed/);
    await expect(page.locator("#sidebar-collapsed")).toBeVisible();

    await page.click("#sidebar-open");
    await expect(page.locator("#sidebar")).not.toHaveClass(/sidebar--closed/);
  });

  test("runs hello workflow and shows outputs", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    const name = `Playwright-${Date.now()}`;
    const { runId, prefix } = await runWorkflowViaDialog(page, helloWorkflowPath, { name });
    await waitForRunStatus(page, prefix, "finished");

    await page.click("#tab-runs");
    await page.locator(".run-row.status-finished", { hasText: prefix }).first().click();
    await expect(page.locator(".run-header__meta .mono", { hasText: runId })).toBeVisible();

    await page.locator(".run-tab[data-tab='outputs']").click();
    await expect(page.locator(".output-table__title", { hasText: "output" })).toBeVisible();
    await expect(page.locator(".output-table pre")).toContainText(`Hello, ${name}`);

    await page.locator(".run-tab[data-tab='timeline']").click();
    const timelineCount = await page.locator(".timeline-row").count();
    expect(timelineCount).toBeGreaterThan(0);

    await page.locator(".run-tab[data-tab='logs']").click();
    const logsText = await page.locator(".logs").textContent();
    expect((logsText ?? "").length).toBeGreaterThan(0);

    await page.locator(".run-row.status-finished", { hasText: prefix }).first().locator("[data-action='copy']").click();
    await expect(page.locator(".toast.toast-info")).toContainText("Run ID copied");
  });

  test("shows error toast on invalid workspace path", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    const badPath = path.join(workspaceRoot, `nope-${Date.now()}`);
    await page.locator(".menu-item[data-menu='file']").click();
    await page.waitForSelector(".menu-dropdown:not(.hidden)");
    await page.locator(".menu-row", { hasText: "Open Workspace" }).click();
    await page.waitForSelector("#workspace-path");
    await page.fill("#workspace-path", badPath);
    await page.click("#workspace-open");

    await expect(page.locator(".toast.toast-error")).toContainText("Failed to open workspace");
    await page.keyboard.press("Escape");
  });

  test("can open and cancel settings dialog", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await openSettingsDialog(page);
    await page.evaluate(() => {
      (document.querySelector("#settings-cancel") as HTMLButtonElement | null)?.click();
    });
    await page.waitForSelector("#settings-panel-open", { state: "detached" });
  });

  test("persists agent settings across reload", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await openSettingsDialog(page);

    const providerInput = page.locator("#settings-provider");
    const modelInput = page.locator("#settings-model");
    const tempInput = page.locator("#settings-temperature");
    const maxTokensInput = page.locator("#settings-max-tokens");

    const initialProvider = await providerInput.inputValue();
    const initialModel = await modelInput.inputValue();
    const initialTemp = await tempInput.inputValue();
    const initialMaxTokens = await maxTokensInput.inputValue();

    const nextProvider = initialProvider === "openai" ? "anthropic" : "openai";
    const nextModel = `playwright-${Date.now()}`;
    const nextTemp = initialTemp === "0.7" ? "0.3" : "0.7";
    const nextMaxTokens = initialMaxTokens === "2048" ? "1536" : "2048";

    await providerInput.selectOption(nextProvider);
    await modelInput.fill(nextModel);
    await tempInput.fill(nextTemp);
    await maxTokensInput.fill(nextMaxTokens);

    await page.evaluate(() => {
      (document.querySelector("#settings-save") as HTMLButtonElement | null)?.click();
    });
    await page.waitForSelector("#settings-panel-open", { state: "detached" });

    await page.reload();
    await waitForAppReady(page);

    await openSettingsDialog(page);
    await expect(providerInput).toHaveValue(nextProvider);
    await expect(modelInput).toHaveValue(nextModel);
    await expect(tempInput).toHaveValue(nextTemp);
    await expect(maxTokensInput).toHaveValue(nextMaxTokens);

    await providerInput.selectOption(initialProvider);
    await modelInput.fill(initialModel);
    await tempInput.fill(initialTemp);
    await maxTokensInput.fill(initialMaxTokens);
    await page.evaluate(() => {
      (document.querySelector("#settings-save") as HTMLButtonElement | null)?.click();
    });
    await page.waitForSelector("#settings-panel-open", { state: "detached" });
  });

  test("can close workspace from menu", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await page.locator(".menu-item[data-menu='file']").click();
    await page.waitForSelector(".menu-dropdown:not(.hidden)");
    await page.locator(".menu-row", { hasText: "Close Workspace" }).click();

    await expect(page.locator("#workspace-select")).toHaveValue("");
    await page.click("#tab-workflows");
    await expect(page.locator(".empty")).toContainText("No workflows found");
  });
});
