import { describe, expect, test } from "bun:test";
import { SmithersDb } from "../src/db/adapter";
import { ensureSmithersTables } from "../src/db/ensure";
import {
  resolveRunCommandExitCode,
  shouldBlockResumeForRunningRun,
} from "../src/cli/run-command-utils";
import { createTestDb } from "./helpers";
import { ddl, schema } from "./schema";

function buildDb() {
  return createTestDb(schema, ddl);
}

describe("smithers list", () => {
  test("lists runs from database", async () => {
    const { db, cleanup } = buildDb();
    ensureSmithersTables(db as any);
    const adapter = new SmithersDb(db as any);

    // Insert test runs
    await adapter.insertRun({
      runId: "run-1",
      workflowName: "test-workflow",
      status: "finished",
      createdAtMs: Date.now() - 1000,
    });
    await adapter.insertRun({
      runId: "run-2",
      workflowName: "test-workflow",
      status: "in-progress",
      createdAtMs: Date.now(),
    });

    const runs = await adapter.listRuns();
    expect(runs.length).toBe(2);
    expect(runs[0].runId).toBe("run-2"); // Most recent first
    expect(runs[1].runId).toBe("run-1");
    cleanup();
  });

  test("filters runs by status", async () => {
    const { db, cleanup } = buildDb();
    ensureSmithersTables(db as any);
    const adapter = new SmithersDb(db as any);

    await adapter.insertRun({
      runId: "run-1",
      workflowName: "test-workflow",
      status: "finished",
      createdAtMs: Date.now() - 1000,
    });
    await adapter.insertRun({
      runId: "run-2",
      workflowName: "test-workflow",
      status: "in-progress",
      createdAtMs: Date.now(),
    });

    const finishedRuns = await adapter.listRuns(50, "finished");
    expect(finishedRuns.length).toBe(1);
    expect(finishedRuns[0].runId).toBe("run-1");
    cleanup();
  });

  test("respects limit parameter", async () => {
    const { db, cleanup } = buildDb();
    ensureSmithersTables(db as any);
    const adapter = new SmithersDb(db as any);

    for (let i = 0; i < 5; i++) {
      await adapter.insertRun({
        runId: `run-${i}`,
        workflowName: "test-workflow",
        status: "finished",
        createdAtMs: Date.now() + i,
      });
    }

    const runs = await adapter.listRuns(2);
    expect(runs.length).toBe(2);
    cleanup();
  });
});

describe("run/resume CLI guards", () => {
  test("blocks resume when run is still marked running and force is false", () => {
    expect(shouldBlockResumeForRunningRun("running", false)).toBe(true);
  });

  test("allows resume when run is running but force is true", () => {
    expect(shouldBlockResumeForRunningRun("running", true)).toBe(false);
  });

  test("does not block resume for non-running statuses", () => {
    expect(shouldBlockResumeForRunningRun("failed", false)).toBe(false);
    expect(shouldBlockResumeForRunningRun("finished", false)).toBe(false);
    expect(shouldBlockResumeForRunningRun(undefined, false)).toBe(false);
  });
});

describe("run command exit code mapping", () => {
  test("maps workflow statuses when no signal interruption occurred", () => {
    expect(
      resolveRunCommandExitCode({
        status: "finished",
        interruptedBySignal: null,
      }),
    ).toBe(0);
    expect(
      resolveRunCommandExitCode({
        status: "waiting-approval",
        interruptedBySignal: null,
      }),
    ).toBe(3);
    expect(
      resolveRunCommandExitCode({
        status: "cancelled",
        interruptedBySignal: null,
      }),
    ).toBe(2);
    expect(
      resolveRunCommandExitCode({
        status: "failed",
        interruptedBySignal: null,
      }),
    ).toBe(1);
  });

  test("signal interruption overrides workflow status exit code", () => {
    expect(
      resolveRunCommandExitCode({
        status: "cancelled",
        interruptedBySignal: "SIGINT",
      }),
    ).toBe(130);
    expect(
      resolveRunCommandExitCode({
        status: "failed",
        interruptedBySignal: "SIGTERM",
      }),
    ).toBe(143);
  });
});
