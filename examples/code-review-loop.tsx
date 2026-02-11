import { smithers, Workflow, Task, Sequence, Ralph } from "smithers-orchestrator";
import { ToolLoopAgent as Agent, Output } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { read, edit, bash, grep } from "smithers-orchestrator/tools";
import { drizzle } from "drizzle-orm/bun-sqlite";
import {
  sqliteTable,
  text,
  integer,
  primaryKey,
} from "drizzle-orm/sqlite-core";
import { z } from "zod";

// Define tables
const inputTable = sqliteTable("input", {
  runId: text("run_id").primaryKey(),
  directory: text("directory").notNull(),
  focus: text("focus").notNull(), // e.g. "error handling", "type safety", "performance"
});

const reviewTable = sqliteTable(
  "review",
  {
    runId: text("run_id").notNull(),
    nodeId: text("node_id").notNull(),
    iteration: integer("iteration").notNull().default(0),
    approved: integer("approved", { mode: "boolean" }).notNull(),
    feedback: text("feedback").notNull(),
    issues: text("issues", { mode: "json" }).$type<string[]>(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.runId, t.nodeId, t.iteration] }),
  })
);

const fixTable = sqliteTable(
  "fix",
  {
    runId: text("run_id").notNull(),
    nodeId: text("node_id").notNull(),
    iteration: integer("iteration").notNull().default(0),
    filesChanged: text("files_changed", { mode: "json" }).$type<string[]>(),
    changesSummary: text("changes_summary").notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.runId, t.nodeId, t.iteration] }),
  })
);

const outputTable = sqliteTable(
  "output",
  {
    runId: text("run_id").notNull(),
    nodeId: text("node_id").notNull(),
    finalSummary: text("final_summary").notNull(),
    totalIterations: integer("total_iterations").notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.runId, t.nodeId] }),
  })
);

export const schema = {
  input: inputTable,
  output: outputTable,
  review: reviewTable,
  fix: fixTable,
};

export const db = drizzle("./examples/code-review-loop.db", { schema });

// Create tables
(db as any).$client.exec(`
  CREATE TABLE IF NOT EXISTS input (
    run_id TEXT PRIMARY KEY,
    directory TEXT NOT NULL,
    focus TEXT NOT NULL
  );
  CREATE TABLE IF NOT EXISTS review (
    run_id TEXT NOT NULL,
    node_id TEXT NOT NULL,
    iteration INTEGER NOT NULL DEFAULT 0,
    approved INTEGER NOT NULL,
    feedback TEXT NOT NULL,
    issues TEXT,
    PRIMARY KEY (run_id, node_id, iteration)
  );
  CREATE TABLE IF NOT EXISTS fix (
    run_id TEXT NOT NULL,
    node_id TEXT NOT NULL,
    iteration INTEGER NOT NULL DEFAULT 0,
    files_changed TEXT,
    changes_summary TEXT NOT NULL,
    PRIMARY KEY (run_id, node_id, iteration)
  );
  CREATE TABLE IF NOT EXISTS output (
    run_id TEXT NOT NULL,
    node_id TEXT NOT NULL,
    final_summary TEXT NOT NULL,
    total_iterations INTEGER NOT NULL,
    PRIMARY KEY (run_id, node_id)
  );
`);

const reviewOutputSchema = z.object({
  approved: z.boolean(),
  feedback: z.string(),
  issues: z.array(z.string()).optional(),
});

const fixOutputSchema = z.object({
  filesChanged: z.array(z.string()),
  changesSummary: z.string(),
});

const reviewAgent = new Agent({
  model: anthropic("claude-sonnet-4-20250514"),
  tools: { read, grep, bash },
  output: Output.object({ schema: reviewOutputSchema }),
  instructions: `You are a senior code reviewer. Review the codebase thoroughly.
If everything looks good, set approved to true and say "LGTM" in feedback.
If there are issues, set approved to false and list specific issues to fix.`,
});

const fixAgent = new Agent({
  model: anthropic("claude-sonnet-4-20250514"),
  tools: { read, grep },  // Remove edit to prevent actual changes
  instructions: `You are a senior software engineer. Analyze the issues and describe what fixes would be needed.
Do NOT actually make changes - just describe what you WOULD fix.

Respond with ONLY a JSON object:
{"filesChanged": ["path/to/file1.ts"], "changesSummary": "Description of fixes needed"}`,
});

export default smithers(db, (ctx) => {
  const latestReview = ctx.outputs.review?.[ctx.outputs.review.length - 1];
  const isApproved = latestReview?.approved ?? false;

  return (
    <Workflow name="code-review-loop">
      <Ralph until={isApproved} maxIterations={3} onMaxReached="return-last">
        <Sequence>
          <Task id="review" output={schema.review} agent={reviewAgent}>
            {`Review the codebase in directory: ${ctx.input.directory}
Focus area: ${ctx.input.focus}

${latestReview ? `Previous issues that were supposedly fixed:\n${latestReview.issues?.join("\n")}` : "This is the initial review."}

Use the tools to explore the code. Look for:
- Code quality issues
- Potential bugs  
- Missing error handling
- Type safety problems
- Any issues related to: ${ctx.input.focus}`}
          </Task>
          <Task id="fix" output={schema.fix} agent={fixAgent} skipIf={isApproved}>
            {`Fix the issues found in the code review:

Feedback: ${ctx.outputMaybe(schema.review, { nodeId: "review" })?.feedback ?? "No feedback yet"}

Issues to fix:
${ctx.outputMaybe(schema.review, { nodeId: "review" })?.issues?.join("\n") ?? "No specific issues listed"}

Directory: ${ctx.input.directory}

IMPORTANT: After analysis, output EXACTLY this JSON format (no other text):
{"filesChanged": ["file1.ts", "file2.ts"], "changesSummary": "What changes are needed"}`}
          </Task>
        </Sequence>
      </Ralph>
      <Task id="summary" output={schema.output}>
        {{
          finalSummary: isApproved
            ? "Code review passed - LGTM!"
            : `Review completed after ${ctx.outputs.review?.length ?? 0} iterations`,
          totalIterations: ctx.outputs.review?.length ?? 0,
        }}
      </Task>
    </Workflow>
  );
});
