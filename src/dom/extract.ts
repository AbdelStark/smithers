import type { XmlNode, XmlElement, TaskDescriptor } from "../types";
import { getTableName } from "drizzle-orm";

export type HostNode = HostElement | HostText;

export type HostElement = {
  kind: "element";
  tag: string;
  props: Record<string, string>;
  rawProps: Record<string, any>;
  children: HostNode[];
};

export type HostText = {
  kind: "text";
  text: string;
};

export type ExtractResult = {
  xml: XmlNode | null;
  tasks: TaskDescriptor[];
  mountedTaskIds: string[];
};

function toXmlNode(node: HostNode): XmlNode {
  if (node.kind === "text") {
    return { kind: "text", text: node.text };
  }
  const element: XmlElement = {
    kind: "element",
    tag: node.tag,
    props: node.props ?? {},
    children: node.children.map(toXmlNode),
  };
  return element;
}

export function extractFromHost(root: HostNode | null): ExtractResult {
  if (!root) {
    return { xml: null, tasks: [], mountedTaskIds: [] };
  }

  const tasks: TaskDescriptor[] = [];
  const mountedTaskIds: string[] = [];
  const seen = new Set<string>();
  let ordinal = 0;

  function walk(node: HostNode, ctx: { iteration: number; parallelStack: { id: string; max?: number }[] }) {
    if (node.kind === "text") return;

    let iteration = ctx.iteration;
    const parallelStack = ctx.parallelStack;

    if (node.tag === "smithers:ralph") {
      const rawIteration = node.rawProps?.__iteration;
      if (typeof rawIteration === "number") {
        iteration = rawIteration;
      }
    }

    let nextParallelStack = parallelStack;
    if (node.tag === "smithers:parallel") {
      const max = typeof node.rawProps?.maxConcurrency === "number" ? node.rawProps.maxConcurrency : undefined;
      const id = node.rawProps?.__parallelId ?? `parallel-${parallelStack.length}`;
      nextParallelStack = [...parallelStack, { id, max }];
    }

    if (node.tag === "smithers:task") {
      const raw = node.rawProps || {};
      const nodeId = raw.id;
      if (!nodeId || typeof nodeId !== "string") {
        throw new Error("Task id is required and must be a string.");
      }
      if (seen.has(nodeId)) {
        throw new Error(`Duplicate Task id detected: ${nodeId}`);
      }
      seen.add(nodeId);

      const outputTable = raw.output;
      if (!outputTable) {
        throw new Error(`Task ${nodeId} is missing output table.`);
      }

      const outputTableName = getTableName(outputTable as any);
      const needsApproval = Boolean(raw.needsApproval);
      const skipIf = Boolean(raw.skipIf);
      const retries = typeof raw.retries === "number" ? raw.retries : 0;
      const timeoutMs = typeof raw.timeoutMs === "number" ? raw.timeoutMs : null;
      const continueOnFail = Boolean(raw.continueOnFail);

      const agent = raw.agent;
      const prompt = agent ? String(raw.children ?? "") : undefined;
      const staticPayload = agent ? undefined : raw.children;

      const parallelGroup = nextParallelStack[nextParallelStack.length - 1];

      const descriptor: TaskDescriptor = {
        nodeId,
        ordinal: ordinal++,
        iteration,
        outputTable,
        outputTableName,
        needsApproval,
        skipIf,
        retries,
        timeoutMs,
        continueOnFail,
        agent,
        prompt,
        staticPayload,
        label: raw.label,
        meta: raw.meta,
        parallelGroupId: parallelGroup?.id,
        parallelMaxConcurrency: parallelGroup?.max,
      };
      tasks.push(descriptor);
      mountedTaskIds.push(nodeId);
    }

    for (const child of node.children) {
      walk(child, { iteration, parallelStack: nextParallelStack });
    }
  }

  walk(root, { iteration: 0, parallelStack: [] });

  return { xml: toXmlNode(root), tasks, mountedTaskIds };
}
