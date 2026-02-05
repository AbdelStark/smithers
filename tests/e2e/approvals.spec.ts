import { test, expect } from "@playwright/test";
import {
  waitForAppReady,
  ensureWorkspace,
  approvalWorkflowPath,
  runWorkflowViaDialog,
  waitForRunStatus,
  startFreshSession,
} from "./utils";

test.describe("Approval Flow", () => {
  test("approve workflow completes", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);
    await startFreshSession(page);

    const { prefix } = await runWorkflowViaDialog(page, approvalWorkflowPath, { name: "Approve" });
    await waitForRunStatus(page, prefix, "waiting-approval");

    await page.locator(".run-row.status-waiting-approval", { hasText: prefix }).first().click();
    await expect(page.locator(".approval-card__title")).toContainText("Approval Required");

    await page.locator(".approval-card .btn.btn-primary", { hasText: "Approve" }).click();
    await waitForRunStatus(page, prefix, "finished");

    await page.locator(".run-row.status-finished", { hasText: prefix }).first().click();
    await page.locator(".run-tab[data-tab='outputs']").click();
    await expect(page.locator(".output-table pre")).toContainText("Approved: Approve");
    await expect(page.locator(".output-table pre")).toContainText("Done: Approve");
  });

  test("deny workflow marks run failed", async ({ page }) => {
    await waitForAppReady(page);
    await ensureWorkspace(page);
    await startFreshSession(page);

    const { prefix } = await runWorkflowViaDialog(page, approvalWorkflowPath, { name: "Deny" });
    await waitForRunStatus(page, prefix, "waiting-approval");

    await page.locator(".run-row.status-waiting-approval", { hasText: prefix }).first().click();
    await page.locator(".approval-card .btn.btn-danger", { hasText: "Deny" }).click();

    await waitForRunStatus(page, prefix, "failed");
  });
});
