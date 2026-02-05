import { test, expect } from "@playwright/test";
import {
  waitForAppReady,
  ensureWorkspace,
  helloWorkflowPath,
  runWorkflowViaDialog,
  waitForRunStatus,
  openMenu,
} from "./utils";

test.describe("Menus and Shortcuts", () => {
  test("workflow menu opens run dialog", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await openMenu(page, "workflow");
    await page.locator(".menu-row", { hasText: "Run Workflow" }).click();
    await expect(page.locator("#workflow-select")).toBeVisible();
    await page.keyboard.press("Escape");
  });

  test("help menu shows docs toast", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await openMenu(page, "help");
    await page.locator(".menu-row", { hasText: "Docs" }).click();
    await expect(page.locator(".toast.toast-info")).toContainText("smithers.sh");
  });

  test("view menu zoom controls graph", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    const { prefix } = await runWorkflowViaDialog(page, helloWorkflowPath, { name: "Zoom" });
    await waitForRunStatus(page, prefix, "finished");
    await page.locator(".run-row.status-finished", { hasText: prefix }).first().click();
    await page.locator(".run-tab[data-tab='graph']").click();

    const transformBefore = await page.locator(".graph-canvas").evaluate((el) => el.style.transform);
    await openMenu(page, "view");
    await page.locator(".menu-row", { hasText: "Zoom In" }).click();
    const transformAfter = await page.locator(".graph-canvas").evaluate((el) => el.style.transform);
    expect(transformAfter).not.toEqual(transformBefore);
  });

  test("keyboard shortcuts toggle sidebar and artifacts", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await page.keyboard.press("Control+\\");
    await expect(page.locator("#sidebar")).toHaveClass(/sidebar--closed/);

    await page.keyboard.press("Control+Shift+\\");
    await expect(page.locator("body")).toHaveClass(/artifacts-hidden/);

    await page.keyboard.press("Control+\\");
    await expect(page.locator("#sidebar")).not.toHaveClass(/sidebar--closed/);
  });

  test("keyboard shortcut opens run dialog", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);

    await page.keyboard.press("Control+R");
    await expect(page.locator("#workflow-select")).toBeVisible();
    await page.keyboard.press("Escape");
  });
});
