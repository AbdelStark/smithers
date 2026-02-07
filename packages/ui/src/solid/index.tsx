import { render } from "solid-js/web";
import App from "./App";
import { RpcProvider } from "./contexts/rpc-context";
import { QueryProvider, queryClient } from "./contexts/query-context";
import { setAppState, pushToast, appState } from "./stores/app-store";
import { ChatAgent } from "../chat/ChatAgent.js";
import type { RpcClient, RpcFactory, RpcHandlers } from "../rpc/types.js";
import type {
  AgentStreamEventDTO,
  SmithersEventDTO,
  FrameSnapshotDTO,
  WorkspaceStateDTO,
} from "@smithers/shared";
import type { AgentEvent, Message } from "../chat/types.js";
import "./globals.css";

class AsyncQueue<T> {
  private queue: T[] = [];
  private resolvers: Array<(value: IteratorResult<T>) => void> = [];
  private closed = false;

  push(value: T) {
    if (this.closed) return;
    const resolver = this.resolvers.shift();
    if (resolver) {
      resolver({ value, done: false });
    } else {
      this.queue.push(value);
    }
  }

  close() {
    this.closed = true;
    while (this.resolvers.length) {
      const resolver = this.resolvers.shift();
      if (resolver) resolver({ value: undefined as T, done: true });
    }
  }

  get length() {
    return this.queue.length;
  }
  get isClosed() {
    return this.closed;
  }

  async *iterator(signal?: AbortSignal): AsyncIterable<T> {
    while (true) {
      if (signal?.aborted) return;
      if (this.queue.length > 0) {
        yield this.queue.shift() as T;
        continue;
      }
      if (this.closed) return;
      const value = await new Promise<IteratorResult<T>>((resolve) => {
        this.resolvers.push(resolve);
      });
      if (value.done) return;
      yield value.value as T;
    }
  }
}

class AgentEventMux {
  private queues = new Map<string, AsyncQueue<AgentEvent>>();

  get(runId: string): AsyncQueue<AgentEvent> {
    const existing = this.queues.get(runId);
    if (existing) return existing;
    const queue = new AsyncQueue<AgentEvent>();
    this.queues.set(runId, queue);
    return queue;
  }

  push(runId: string, event: AgentEvent) {
    const queue = this.get(runId);
    queue.push(event);
    if (event.type === "agent_end") queue.close();
  }

  async *consume(runId: string, signal?: AbortSignal): AsyncIterable<AgentEvent> {
    const queue = this.get(runId);
    try {
      for await (const event of queue.iterator(signal)) {
        yield event;
      }
    } finally {
      if (queue.isClosed && queue.length === 0) this.queues.delete(runId);
    }
  }
}

let rpc: RpcClient;
const eventMux = new AgentEventMux();

export function getRpc(): RpcClient {
  return rpc;
}

class BunAgentTransport {
  private sessionId: string;
  constructor(sessionId: string) {
    this.sessionId = sessionId;
  }

  async *run(
    _messages: Message[],
    userMessage: Message,
    _config: unknown,
    signal?: AbortSignal,
  ) {
    const text =
      typeof (userMessage as any).content === "string"
        ? (userMessage as any).content
        : Array.isArray((userMessage as any).content)
          ? (userMessage as any).content
              .filter((c: any) => c.type === "text")
              .map((c: any) => c.text)
              .join("")
          : "";
    const attachments = (userMessage as any).attachments;
    const { runId } = await rpc.request.sendChatMessage({
      sessionId: this.sessionId,
      text,
      attachments,
    });
    const queue = eventMux.get(runId);
    if (signal) {
      signal.addEventListener("abort", () => {
        rpc.request
          .abortChatRun({ sessionId: this.sessionId, runId })
          .catch(() => {});
        queue.close();
      });
    }
    for await (const event of eventMux.consume(runId, signal)) {
      yield event;
      if (event.type === "agent_end") break;
    }
  }

  async *continue(
    _messages: Message[],
    _config: unknown,
    signal?: AbortSignal,
  ) {
    const { runId } = await rpc.request.sendChatMessage({
      sessionId: this.sessionId,
      text: "",
    });
    const queue = eventMux.get(runId);
    if (signal) {
      signal.addEventListener("abort", () => {
        rpc.request
          .abortChatRun({ sessionId: this.sessionId, runId })
          .catch(() => {});
        queue.close();
      });
    }
    for await (const event of eventMux.consume(runId, signal)) {
      yield event;
      if (event.type === "agent_end") break;
    }
  }
}

export { BunAgentTransport };

async function bootstrap() {
  const [settings, secretStatus] = await Promise.all([
    rpc.request.getSettings({}),
    rpc.request.getSecretStatus({}),
  ]);
  setAppState({
    settings,
    secretStatus,
    inspectorOpen: settings.ui.workflowPanel.isOpen,
  });

  const sessions = await rpc.request.listChatSessions({});
  setAppState("sessions", sessions);

  let sessionId: string;
  if (sessions.length > 0) {
    sessionId = sessions[0]!.sessionId;
  } else {
    const created = await rpc.request.createChatSession({
      title: "New Session",
    });
    sessionId = created.sessionId;
    const updated = await rpc.request.listChatSessions({});
    setAppState("sessions", updated);
  }
  await bootstrapSession(sessionId);

  const ws = await rpc.request.getWorkspaceState({});
  setAppState({ workspaceRoot: ws.root, workflows: ws.workflows });

  const runs = await rpc.request.listRuns({ status: "all" });
  setAppState(
    "runs",
    ws.root ? runs.filter((r) => r.workspaceRoot === ws.root) : runs,
  );
}

async function bootstrapSession(sessionId: string) {
  setAppState("sessionId", sessionId);
  const session = await rpc.request.getChatSession({ sessionId });
  const transport = new BunAgentTransport(sessionId);
  const agent = new ChatAgent({
    transport,
    initialState: { messages: (session.messages ?? []) as Message[] },
  });
  setAppState("agent", agent);
}

export async function switchSession(sessionId: string) {
  await bootstrapSession(sessionId);
}

export async function createNewSession() {
  const result = await rpc.request.createChatSession({
    title: "New Session",
  });
  const sessions = await rpc.request.listChatSessions({});
  setAppState("sessions", sessions);
  await bootstrapSession(result.sessionId);
}

export async function refreshRuns() {
  const runs = await rpc.request.listRuns({ status: "all" });
  const root = appState.workspaceRoot;
  setAppState(
    "runs",
    root ? runs.filter((r) => r.workspaceRoot === root) : runs,
  );
}

export async function focusRun(runId: string) {
  setAppState({
    selectedRunId: runId,
    contextRunId: runId,
    inspectorOpen: true,
  });
  const detail = await rpc.request.getRun({ runId });
  setAppState("runDetails", runId, detail);
  const events = await rpc.request.getRunEvents({ runId, afterSeq: -1 });
  setAppState("runEvents", runId, events.events);
  setAppState("runEventSeq", runId, events.lastSeq);
  try {
    const frame = await rpc.request.getFrame({ runId });
    setAppState("frames", runId, frame);
  } catch {
    // frame may not exist yet
  }
  try {
    const outputs = await rpc.request.getRunOutputs({ runId });
    setAppState("outputs", runId, outputs);
  } catch {
    // outputs may not exist yet
  }
  try {
    const attempts = await rpc.request.getRunAttempts({ runId });
    setAppState("attempts", runId, attempts);
  } catch {
    // attempts may not exist yet
  }
}

export function startApp(createRpc: RpcFactory) {
  rpc = createRpc({
    requests: {},
    messages: {
      agentEvent: (payload: AgentStreamEventDTO) => {
        eventMux.push(payload.runId, payload.event as AgentEvent);
      },
      chatMessage: ({ sessionId, message }: any) => {
        if (sessionId === appState.sessionId && appState.agent) {
          appState.agent.appendMessage(message as any);
        }
      },
      workflowEvent: (payload: any) => {
        const runId = payload.runId;
        setAppState("runEvents", runId, (prev: any) => [
          ...(prev ?? []),
          payload,
        ]);
        setAppState("runEventSeq", runId, payload.seq);
        void refreshRuns();
      },
      workflowFrame: (frame: any) => {
        setAppState("frames", frame.runId, frame);
      },
      workspaceState: (payload: any) => {
        setAppState({
          workspaceRoot: payload.root,
          workflows: payload.workflows,
        });
        void refreshRuns();
      },
      toast: (payload: any) => {
        pushToast(payload.level, payload.message);
      },
    },
  });

  const root = document.getElementById("app") ?? document.body;
  render(
    () => (
      <RpcProvider client={rpc}>
        <QueryProvider>
          <App />
        </QueryProvider>
      </RpcProvider>
    ),
    root,
  );

  bootstrap().catch((err) => {
    console.error("Bootstrap failed:", err);
    pushToast("error", `Bootstrap failed: ${err?.message ?? err}`);
  });
}
