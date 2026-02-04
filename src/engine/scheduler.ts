import type { XmlNode, TaskDescriptor } from "../types";

export type PlanNode =
  | { kind: "task"; nodeId: string }
  | { kind: "sequence"; children: PlanNode[] }
  | { kind: "parallel"; children: PlanNode[]; maxConcurrency?: number }
  | { kind: "ralph"; children: PlanNode[]; until: boolean; maxIterations: number; onMaxReached: "fail" | "return-last" }
  | { kind: "group"; children: PlanNode[] };

export type TaskState = "pending" | "waiting-approval" | "in-progress" | "finished" | "failed" | "cancelled" | "skipped";

export type TaskStateMap = Map<string, TaskState>;

export type ScheduleResult = {
  runnable: TaskDescriptor[];
  pendingExists: boolean;
  waitingApprovalExists: boolean;
};

export type RalphMeta = {
  until: boolean;
  maxIterations: number;
  onMaxReached: "fail" | "return-last";
};

function key(nodeId: string, iteration: number) {
  return `${nodeId}::${iteration}`;
}

function parseBool(value: string | undefined): boolean {
  if (!value) return false;
  return value === "true" || value === "1";
}

function parseNum(value: string | undefined, fallback: number): number {
  const num = value ? Number(value) : NaN;
  return Number.isFinite(num) ? num : fallback;
}

export function buildPlanTree(xml: XmlNode | null): PlanNode | null {
  if (!xml) return null;
  if (xml.kind === "text") return null;
  const tag = xml.tag;
  const children = xml.children.map(buildPlanTree).filter(Boolean) as PlanNode[];
  if (tag === "smithers:task") {
    const nodeId = xml.props.id;
    if (!nodeId) return null;
    return { kind: "task", nodeId };
  }
  if (tag === "smithers:sequence") {
    return { kind: "sequence", children };
  }
  if (tag === "smithers:parallel") {
    const max = parseNum(xml.props.maxConcurrency, NaN);
    return { kind: "parallel", children, maxConcurrency: Number.isFinite(max) ? max : undefined };
  }
  if (tag === "smithers:ralph") {
    const until = parseBool(xml.props.until);
    const maxIterations = parseNum(xml.props.maxIterations, 5);
    const onMaxReached = (xml.props.onMaxReached as "fail" | "return-last") ?? "return-last";
    return { kind: "ralph", children, until, maxIterations, onMaxReached };
  }
  return { kind: "group", children };
}

export function findFirstRalph(plan: PlanNode | null): RalphMeta | null {
  if (!plan) return null;
  if (plan.kind === "ralph") {
    return { until: plan.until, maxIterations: plan.maxIterations, onMaxReached: plan.onMaxReached };
  }
  const children = plan.kind === "task" ? [] : plan.children;
  for (const child of children) {
    const found = findFirstRalph(child);
    if (found) return found;
  }
  return null;
}

function isTerminal(state: TaskState, desc: TaskDescriptor): boolean {
  if (state === "finished" || state === "skipped") return true;
  if (state === "failed") return desc.continueOnFail;
  return false;
}

export function scheduleTasks(plan: PlanNode | null, states: TaskStateMap, descriptors: Map<string, TaskDescriptor>): ScheduleResult {
  const runnable: TaskDescriptor[] = [];
  let pendingExists = false;
  let waitingApprovalExists = false;

  function walk(node: PlanNode): { terminal: boolean } {
    switch (node.kind) {
      case "task": {
        const desc = descriptors.get(node.nodeId);
        if (!desc) return { terminal: true };
        const state = states.get(key(desc.nodeId, desc.iteration)) ?? "pending";
        if (state === "waiting-approval") waitingApprovalExists = true;
        if (state === "pending" || state === "cancelled") pendingExists = true;
        const terminal = isTerminal(state, desc);
        if (!terminal && (state === "pending" || state === "cancelled")) {
          runnable.push(desc);
        }
        return { terminal };
      }
      case "sequence": {
        for (const child of node.children) {
          const res = walk(child);
          if (!res.terminal) {
            return { terminal: false };
          }
        }
        return { terminal: true };
      }
      case "parallel": {
        let terminal = true;
        for (const child of node.children) {
          const res = walk(child);
          if (!res.terminal) terminal = false;
        }
        return { terminal };
      }
      case "ralph": {
        let terminal = true;
        for (const child of node.children) {
          const res = walk(child);
          if (!res.terminal) terminal = false;
        }
        return { terminal };
      }
      case "group": {
        let terminal = true;
        for (const child of node.children) {
          const res = walk(child);
          if (!res.terminal) terminal = false;
        }
        return { terminal };
      }
      default:
        return { terminal: true };
    }
  }

  if (plan) {
    walk(plan);
  }

  return { runnable, pendingExists, waitingApprovalExists };
}

export function buildStateKey(nodeId: string, iteration: number) {
  return key(nodeId, iteration);
}
