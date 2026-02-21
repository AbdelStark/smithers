import type { AgentLike } from "./AgentLike";

export type TaskDescriptor = {
  nodeId: string;
  ordinal: number;
  iteration: number;
  ralphId?: string;
  worktreeId?: string;
  worktreePath?: string;
  worktreeBranch?: string;
  outputTable: any | null;
  outputTableName: string;
  outputSchema?: import("zod").ZodObject<any>;
  parallelGroupId?: string;
  parallelMaxConcurrency?: number;
  needsApproval: boolean;
  skipIf: boolean;
  retries: number;
  timeoutMs: number | null;
  continueOnFail: boolean;
  /** Agent or array of agents [primary, fallback1, fallback2, ...]. Tries in order until one succeeds. */
  agent?: AgentLike | AgentLike[];
  prompt?: string;
  staticPayload?: unknown;
  computeFn?: () => unknown | Promise<unknown>;
  label?: string;
  meta?: Record<string, unknown>;
};
