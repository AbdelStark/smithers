/** @jsxImportSource smithers */
import { describe, expect, test } from "bun:test";
import { Workflow } from "../src/components";
import { Worktree, MergeQueue, Task } from "../src/components";
import { SmithersRenderer } from "../src/dom/renderer";
import { createTestDb, sleep } from "./helpers";
import { ddl, outputA, schema } from "./schema";
import { runWorkflow, smithers } from "../src/index";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

describe("Worktree & MergeQueue", () => {
  test("extractor attaches worktree metadata to tasks", async () => {
    const renderer = new SmithersRenderer();
    const wtPath = "/tmp/smithers-wt-test";
    const result = await renderer.render(
      <Workflow name="wt">
        <Worktree id="wt-1" path={wtPath}>
          <Task id="t1" output={outputA}>{{ value: 1 }}</Task>
        </Worktree>
      </Workflow>,
    );

    const t = result.tasks.find((x) => x.nodeId === "t1")!;
    expect(t.worktreeId).toBe("wt-1");
    expect(t.worktreePath).toBe(wtPath);
    expect(t.rootDirOverride).toBe(wtPath);
  });

  test("merge-queue limits concurrent worktrees", async () => {
    const { db, cleanup } = createTestDb(schema, ddl);

    let current = 0;
    let max = 0;
    const slowAgent: any = {
      id: "slow",
      tools: {},
      async generate({ prompt }: { prompt: string }) {
        current += 1;
        if (current > max) max = current;
        await sleep(60);
        current -= 1;
        const value = Number((prompt ?? "").split(":")[1] ?? 0);
        return { output: { value } };
      },
    };

    const dir1 = mkdtempSync(join(tmpdir(), "smithers-wt-a-"));
    const dir2 = mkdtempSync(join(tmpdir(), "smithers-wt-b-"));

    try {
      const workflow = smithers(db as any, () => (
        <Workflow name="queue">
          <MergeQueue maxWorktrees={1}>
            <Worktree path={dir1}>
              <Task id="w1" output={outputA} agent={slowAgent}>{"v:1"}</Task>
            </Worktree>
            <Worktree path={dir2}>
              <Task id="w2" output={outputA} agent={slowAgent}>{"v:2"}</Task>
            </Worktree>
          </MergeQueue>
        </Workflow>
      ));

      const result = await runWorkflow(workflow, { input: {}, maxConcurrency: 2 });
      expect(result.status).toBe("finished");
      // Despite global maxConcurrency=2, merge-queue=1 caps concurrency to 1
      expect(max).toBeLessThanOrEqual(1);
    } finally {
      cleanup();
      try { rmSync(dir1, { recursive: true, force: true }); } catch {}
      try { rmSync(dir2, { recursive: true, force: true }); } catch {}
    }
  });

  test("engine honors per-task root override from <Worktree>", async () => {
    const { db, cleanup } = createTestDb(schema, ddl);
    const worktreeDir = mkdtempSync(join(tmpdir(), "smithers-wt-cwd-"));
    const otherRoot = mkdtempSync(join(tmpdir(), "smithers-root-"));
    const file = join(worktreeDir, "sample.txt");
    writeFileSync(file, "abc123", "utf8");

    const toolAgent = {
      id: "tool-reader",
      tools: (await import("../src/tools")).tools,
      async generate() {
        const { read }: any = await import("../src/tools");
        const content = await read.execute({ path: "sample.txt" });
        return { output: { value: content.length } };
      },
    } as any;

    try {
      const workflow = smithers(db as any, () => (
        <Workflow name="cwd-override">
          <Worktree path={worktreeDir}>
            <Task id="read" output={outputA} agent={toolAgent}>read</Task>
          </Worktree>
        </Workflow>
      ));

      const result = await runWorkflow(workflow, { input: {}, rootDir: otherRoot });
      expect(result.status).toBe("finished");
      const rows = await (db as any).select().from(outputA);
      expect(rows?.[0]?.value).toBe(6);
    } finally {
      cleanup();
      try { rmSync(worktreeDir, { recursive: true, force: true }); } catch {}
      try { rmSync(otherRoot, { recursive: true, force: true }); } catch {}
    }
  });

  test("skipIf prevents subtree execution for Worktree and MergeQueue", async () => {
    const renderer = new SmithersRenderer();
    const result = await renderer.render(
      <Workflow name="skip">
        <MergeQueue skipIf>
          <Worktree path="/tmp/should-not-exist" skipIf>
            <Task id="never" output={outputA}>{{ value: 42 }}</Task>
          </Worktree>
        </MergeQueue>
      </Workflow>,
    );
    const ids = result.tasks.map((t) => t.nodeId);
    expect(ids.includes("never")).toBe(false);
  });

  test("scheduler plan tree includes merge-queue and worktree nodes", async () => {
    const renderer = new SmithersRenderer();
    const result = await renderer.render(
      <Workflow name="plan">
        <MergeQueue maxWorktrees={2}>
          <Worktree id="wt-a" path="/tmp/a">
            <Task id="task-a" output={outputA}>{{ value: 1 }}</Task>
          </Worktree>
        </MergeQueue>
      </Workflow>,
    );
    const { buildPlanTree } = await import("../src/engine/scheduler");
    const tree = buildPlanTree(result.xml).plan!;
    expect(tree.kind).toBe("sequence");
    const mq = (tree as any).children[0];
    expect(mq.kind).toBe("merge-queue");
    const wt = mq.children[0];
    expect(wt.kind).toBe("worktree");
    const t = wt.children[0];
    expect(t.kind).toBe("task");
    expect(t.nodeId).toBe("task-a");
  });

  test("task-level rootDirOverride overrides enclosing Worktree path", async () => {
    const { db, cleanup } = createTestDb(schema, ddl);
    const worktreeDir = mkdtempSync(join(tmpdir(), "smithers-wt-cwd-"));
    const otherRoot = mkdtempSync(join(tmpdir(), "smithers-root-"));
    const file = join(otherRoot, "sample.txt");
    writeFileSync(file, "xyz", "utf8");

    const toolAgent = {
      id: "tool-reader",
      tools: (await import("../src/tools")).tools,
      async generate() {
        const { read }: any = await import("../src/tools");
        const content = await read.execute({ path: "sample.txt" });
        return { output: { value: content.length } };
      },
    } as any;

    try {
      const workflow = smithers(db as any, () => (
        <Workflow name="cwd-override-task">
          <Worktree path={worktreeDir}>
            <Task id="read2" output={outputA} agent={toolAgent} rootDirOverride={otherRoot}>read</Task>
          </Worktree>
        </Workflow>
      ));

      const result = await runWorkflow(workflow, { input: {}, rootDir: worktreeDir });
      expect(result.status).toBe("finished");
      const rows = await (db as any).select().from(outputA);
      expect(rows?.[0]?.value).toBe(3);
    } finally {
      cleanup();
      try { rmSync(worktreeDir, { recursive: true, force: true }); } catch {}
      try { rmSync(otherRoot, { recursive: true, force: true }); } catch {}
    }
  });
});

