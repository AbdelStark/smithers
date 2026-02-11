import { smithers, Workflow, Task, Sequence } from "smithers-orchestrator";
import { ToolLoopAgent as Agent } from "ai";
import { anthropic } from "@ai-sdk/anthropic";
import { drizzle } from "drizzle-orm/bun-sqlite";
import {
  sqliteTable,
  text,
  integer,
  primaryKey,
} from "drizzle-orm/sqlite-core";

// Define tables
const inputTable = sqliteTable("input", {
  runId: text("run_id").primaryKey(),
  topic: text("topic").notNull(),
});

const researchTable = sqliteTable(
  "research",
  {
    runId: text("run_id").notNull(),
    nodeId: text("node_id").notNull(),
    summary: text("summary").notNull(),
    keyPoints: text("key_points", { mode: "json" }).$type<string[]>(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.runId, t.nodeId] }),
  })
);

const outputTable = sqliteTable(
  "output",
  {
    runId: text("run_id").notNull(),
    nodeId: text("node_id").notNull(),
    article: text("article").notNull(),
    wordCount: integer("word_count").notNull(),
  },
  (t) => ({
    pk: primaryKey({ columns: [t.runId, t.nodeId] }),
  })
);

// Schema and db
export const schema = {
  input: inputTable,
  output: outputTable,
  research: researchTable,
};

export const db = drizzle("./examples/simple-workflow.db", { schema });

// Create agents
const researchAgent = new Agent({
  model: anthropic("claude-sonnet-4-20250514"),
  instructions: "You are a research assistant. Provide concise summaries and key points.",
});

const writerAgent = new Agent({
  model: anthropic("claude-sonnet-4-20250514"),
  instructions: "You are a technical writer. Write clear, engaging content.",
});

// Export workflow
export default smithers(db, (ctx) => (
  <Workflow name="simple-example">
    <Sequence>
      <Task id="research" output={schema.research} agent={researchAgent}>
        {`Research this topic and provide a summary with 3-5 key points: ${ctx.input.topic}`}
      </Task>
      <Task id="write" output={schema.output} agent={writerAgent}>
        {`Write a short article based on this research:
Summary: ${ctx.output(schema.research, { nodeId: "research" }).summary}
Key Points: ${JSON.stringify(ctx.output(schema.research, { nodeId: "research" }).keyPoints)}`}
      </Task>
    </Sequence>
  </Workflow>
));
