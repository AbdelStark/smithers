import {
  type Component,
  For,
  Show,
  createSignal,
  createEffect,
  onCleanup,
  createMemo,
  on,
} from "solid-js";
import { appState, setAppState } from "../stores/app-store";
import { switchSession, createNewSession, focusRun, getRpc } from "../index";
import { shortenPath, truncate, formatTime } from "../lib/format";
import { cn } from "../lib/utils";
import type { ChatAgentState } from "../../chat/ChatAgent.js";
import type {
  Message,
  AssistantMessage,
  TextContent,
  ThinkingContent,
  ToolCall,
  WorkflowCardMessage,
  ToolResultMessage,
  ImageContent,
} from "../../chat/types.js";

// ─── Helpers ──────────────────────────────────────────────

function getUserText(msg: { content: string | (TextContent | ImageContent)[] }): string {
  if (typeof msg.content === "string") return msg.content;
  return msg.content
    .filter((c): c is TextContent => c.type === "text")
    .map((c) => c.text)
    .join("");
}

function renderTextWithCodeBlocks(text: string) {
  const parts = text.split(/(```[\s\S]*?```)/g);
  return (
    <>
      <For each={parts}>
        {(part) =>
          part.startsWith("```") ? (
            <pre class="my-2 rounded-lg bg-background p-3 text-xs font-mono overflow-x-auto whitespace-pre-wrap">
              {part.replace(/^```\w*\n?/, "").replace(/\n?```$/, "")}
            </pre>
          ) : (
            <span class="whitespace-pre-wrap">{part}</span>
          )
        }
      </For>
    </>
  );
}

function toolCallSummary(tc: ToolCall): string {
  const args = Object.keys(tc.arguments).slice(0, 2).join(", ");
  return `→ ${tc.name}(${args})`;
}

function statusBadgeClasses(status: string): string {
  switch (status) {
    case "running":
      return "bg-accent/20 text-accent";
    case "waiting-approval":
      return "bg-warning/20 text-warning";
    case "finished":
      return "bg-success/20 text-success";
    case "failed":
    case "cancelled":
      return "bg-danger/20 text-danger";
    default:
      return "bg-panel-2 text-muted";
  }
}

// ─── Sub-components ───────────────────────────────────────

const UserBubble: Component<{ msg: { content: string | (TextContent | ImageContent)[] }; timestamp: number }> = (props) => (
  <div class="message--user flex justify-end mb-3">
    <div
      class="max-w-[75%] bg-panel-2 px-4 py-2.5 text-foreground text-sm"
      style={{ "border-radius": "18px 18px 4px 18px" }}
    >
      {renderTextWithCodeBlocks(getUserText(props.msg))}
      <div class="mt-1 text-[10px] text-subtle text-right">{formatTime(props.timestamp)}</div>
    </div>
  </div>
);

const AssistantBubble: Component<{ msg: AssistantMessage; streaming?: boolean }> = (props) => (
  <div class="message--assistant flex justify-start mb-3">
    <div class="max-w-[85%]">
      <For each={props.msg.content}>
        {(block) => {
          if (block.type === "text") {
            return (
              <div class="text-sm text-foreground mb-1">
                {renderTextWithCodeBlocks(block.text)}
              </div>
            );
          }
          if (block.type === "thinking") {
            return (
              <div class="border-l-2 border-subtle pl-3 mb-2 text-sm text-muted italic">
                {block.thinking}
              </div>
            );
          }
          if (block.type === "toolCall") {
            return (
              <div class="inline-block mb-1 mr-1 rounded bg-panel-2 px-2 py-0.5 font-mono text-xs text-muted">
                {toolCallSummary(block)}
              </div>
            );
          }
          return null;
        }}
      </For>
      <Show when={props.streaming}>
        <span class="inline-block w-1.5 h-4 bg-accent rounded-sm animate-pulse ml-0.5 align-text-bottom" />
      </Show>
      <Show when={props.msg.errorMessage}>
        <div class="mt-1 text-xs text-danger border border-danger/30 rounded px-2 py-1">
          {props.msg.errorMessage}
        </div>
      </Show>
      <div class="mt-1 text-[10px] text-subtle">
        {formatTime(props.msg.timestamp)}
        <Show when={props.msg.model}>
          <span class="ml-2 font-mono">{props.msg.model}</span>
        </Show>
      </div>
    </div>
  </div>
);

const ToolResultBubble: Component<{ msg: ToolResultMessage }> = (props) => {
  const text = () =>
    props.msg.content
      .filter((c): c is TextContent => c.type === "text")
      .map((c) => c.text)
      .join("");

  return (
    <div class="message--toolResult mb-2 ml-4">
      <div
        class={cn(
          "rounded bg-panel px-3 py-1.5 font-mono text-xs max-w-[80%]",
          props.msg.isError ? "text-danger border border-danger/30" : "text-muted",
        )}
      >
        <span class="text-subtle mr-1">⤶ {props.msg.toolName}:</span>
        {truncate(text(), 200)}
      </div>
    </div>
  );
};

const WorkflowCard: Component<{ msg: WorkflowCardMessage }> = (props) => {
  const handleApprove = async (nodeId: string, iteration?: number) => {
    try {
      await getRpc().request.approveNode({
        runId: props.msg.runId,
        nodeId,
        iteration,
      });
    } catch (e) {
      console.error("Approve failed:", e);
    }
  };

  const handleDeny = async (nodeId: string, iteration?: number) => {
    try {
      await getRpc().request.denyNode({
        runId: props.msg.runId,
        nodeId,
        iteration,
      });
    } catch (e) {
      console.error("Deny failed:", e);
    }
  };

  return (
    <div class="workflow-card mb-3 mx-1">
      <div class="rounded-lg border border-border bg-panel p-3 max-w-[85%]">
        <div class="flex items-center gap-2 mb-2">
          <span class="workflow-card__title text-sm font-medium text-foreground">{props.msg.workflowName}</span>
          <span class={cn("workflow-card__status rounded-full px-2 py-0.5 text-[10px] font-medium", statusBadgeClasses(props.msg.status))}>
            {props.msg.status}
          </span>
        </div>
        <div class="text-xs text-subtle font-mono mb-2">Run: {props.msg.runId.slice(0, 8)}</div>
        <div class="workflow-card__actions flex items-center gap-2 flex-wrap">
          <button
            class="rounded px-2 py-1 text-xs bg-accent/20 text-accent hover:bg-accent/30 transition-colors"
            onClick={() => focusRun(props.msg.runId)}
          >
            Open run
          </button>
          <Show when={props.msg.approvals && props.msg.approvals.length > 0}>
            <For each={props.msg.approvals}>
              {(approval) => (
                <div class="flex items-center gap-1">
                  <button
                    class="rounded px-2 py-1 text-xs bg-success/20 text-success hover:bg-success/30 transition-colors"
                    onClick={() => handleApprove(approval.nodeId, approval.iteration)}
                  >
                    Approve
                  </button>
                  <button
                    class="rounded px-2 py-1 text-xs bg-danger/20 text-danger hover:bg-danger/30 transition-colors"
                    onClick={() => handleDeny(approval.nodeId, approval.iteration)}
                  >
                    Deny
                  </button>
                </div>
              )}
            </For>
          </Show>
        </div>
      </div>
    </div>
  );
};

// ─── Mention Popup ────────────────────────────────────────

interface MentionItem {
  label: string;
  value: string;
  kind: "workflow" | "run";
}

const MentionPopup: Component<{
  items: MentionItem[];
  onSelect: (item: MentionItem) => void;
}> = (props) => (
  <Show when={props.items.length > 0}>
    <div class="mention-box absolute bottom-full left-4 right-4 mb-1 rounded-lg border border-border bg-panel shadow-lg max-h-48 overflow-y-auto z-50">
      <For each={props.items}>
        {(item) => (
          <button
            class="mention-item w-full text-left px-3 py-2 text-sm text-foreground hover:bg-panel-2 transition-colors flex items-center gap-2"
            onMouseDown={(e) => {
              e.preventDefault();
              props.onSelect(item);
            }}
          >
            <span class={cn("text-[10px] rounded px-1 py-0.5 font-mono", item.kind === "workflow" ? "bg-accent/20 text-accent" : "bg-warning/20 text-warning")}>
              {item.kind === "workflow" ? "@wf" : "#run"}
            </span>
            <span class="truncate">{item.label}</span>
          </button>
        )}
      </For>
    </div>
  </Show>
);

// ─── Main ChatView ────────────────────────────────────────

export const ChatView: Component<{ onRunWorkflow?: (preselect?: string) => void }> = (props) => {
  const [inputValue, setInputValue] = createSignal("");
  const [chatState, setChatState] = createSignal<ChatAgentState>({
    messages: [],
    isStreaming: false,
    streamingMessage: null,
  });
  const [mentionItems, setMentionItems] = createSignal<MentionItem[]>([]);

  let messagesEndRef!: HTMLDivElement;
  let textareaRef!: HTMLTextAreaElement;

  createEffect(
    on(
      () => appState.agent,
      (agent) => {
        if (!agent) return;
        const unsub = agent.subscribe((state) => setChatState(state));
        onCleanup(unsub);
      },
    ),
  );

  const allMessages = createMemo((): Message[] => {
    const s = chatState();
    const msgs = [...s.messages];
    if (s.streamingMessage) {
      msgs.push(s.streamingMessage);
    }
    return msgs;
  });

  const isStreaming = () => chatState().isStreaming;
  const hasError = () => chatState().error;

  createEffect(
    on(
      () => allMessages().length,
      () => {
        queueMicrotask(() => messagesEndRef?.scrollIntoView({ behavior: "smooth" }));
      },
    ),
  );

  const resizeTextarea = () => {
    if (!textareaRef) return;
    textareaRef.style.height = "auto";
    const maxH = 12 * 16;
    textareaRef.style.height = `${Math.min(textareaRef.scrollHeight, maxH)}px`;
  };

  const handleInput = (value: string) => {
    setInputValue(value);
    resizeTextarea();
    checkMention(value);
  };

  const checkMention = (value: string) => {
    const wfMatch = value.match(/@workflow\(([^)]*)$/);
    if (wfMatch) {
      const query = wfMatch[1]!.toLowerCase();
      const items: MentionItem[] = appState.workflows
        .filter((w) => (w.name ?? w.path).toLowerCase().includes(query))
        .slice(0, 8)
        .map((w) => ({ label: w.name ?? w.path, value: `@workflow(${w.path})`, kind: "workflow" as const }));
      setMentionItems(items);
      return;
    }
    const runMatch = value.match(/#run\(([^)]*)$/);
    if (runMatch) {
      const query = runMatch[1]!.toLowerCase();
      const items: MentionItem[] = appState.runs
        .filter((r) => r.runId.toLowerCase().includes(query) || r.workflowName?.toLowerCase().includes(query))
        .slice(0, 8)
        .map((r) => ({
          label: `${r.workflowName ?? "run"} (${r.runId.slice(0, 8)})`,
          value: `#run(${r.runId})`,
          kind: "run" as const,
        }));
      setMentionItems(items);
      return;
    }
    setMentionItems([]);
  };

  const handleMentionSelect = (item: MentionItem) => {
    const val = inputValue();
    const pattern = item.kind === "workflow" ? /@workflow\([^)]*$/ : /#run\([^)]*$/;
    const replaced = val.replace(pattern, item.value);
    setInputValue(replaced);
    setMentionItems([]);
    textareaRef?.focus();
  };

  const handleSend = async () => {
    if (isStreaming()) {
      appState.agent?.abort();
      return;
    }
    const text = inputValue().trim();
    if (!text || !appState.agent) return;
    setInputValue("");
    if (textareaRef) {
      textareaRef.style.height = "auto";
    }
    await appState.agent.send(text);
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const toggleInspector = () => {
    setAppState("inspectorOpen", (v) => !v);
  };

  const handleSessionChange = (sessionId: string) => {
    if (sessionId !== appState.sessionId) {
      switchSession(sessionId);
    }
  };

  return (
    <div class="chat-panel flex flex-col flex-1 min-h-0">
      {/* ── Header ─────────────────────────────────── */}
      <header class="flex items-center gap-2 px-4 h-11 shrink-0 border-b border-border bg-panel">
        <select
          id="session-select"
          class="bg-panel-2 text-foreground text-xs rounded px-2 py-1 border border-border min-w-[140px] max-w-[220px] truncate"
          value={appState.sessionId ?? ""}
          onChange={(e) => handleSessionChange(e.currentTarget.value)}
        >
          <For each={appState.sessions}>
            {(s) => (
              <option value={s.sessionId}>
                {s.title || s.sessionId.slice(0, 10)}
              </option>
            )}
          </For>
        </select>

        <button
          id="new-session"
          class="w-6 h-6 rounded flex items-center justify-center text-muted hover:text-foreground hover:bg-panel-2 transition-colors text-sm"
          onClick={() => createNewSession()}
          title="New session"
        >
          +
        </button>

        <div class="flex-1" />

        <Show when={appState.workspaceRoot}>
          <span class="text-[11px] text-subtle font-mono truncate max-w-[180px]" title={appState.workspaceRoot!}>
            {shortenPath(appState.workspaceRoot!)}
          </span>
        </Show>

        <Show when={appState.contextRunId}>
          <span class="text-[10px] text-accent font-mono bg-accent/10 rounded px-1.5 py-0.5">
            run:{appState.contextRunId!.slice(0, 8)}
          </span>
        </Show>

        <button
          id="toggle-sidebar"
          class={cn(
            "w-7 h-7 rounded flex items-center justify-center text-xs transition-colors",
            appState.inspectorOpen ? "bg-accent/20 text-accent" : "text-muted hover:text-foreground hover:bg-panel-2",
          )}
          onClick={toggleInspector}
          title="Toggle inspector (⌘I)"
        >
          ⌘I
        </button>
      </header>

      {/* ── Messages ───────────────────────────────── */}
      <div class="flex-1 overflow-y-auto min-h-0 px-4 py-4">
        <Show
          when={allMessages().length > 0}
          fallback={
            <div class="flex items-center justify-center h-full">
              <span class="text-subtle text-lg">How can I help you today?</span>
            </div>
          }
        >
          <div class="max-w-2xl mx-auto">
            <For each={allMessages()}>
              {(msg, idx) => {
                const isStreamingMsg = () =>
                  chatState().streamingMessage !== null &&
                  idx() === allMessages().length - 1 &&
                  msg.role === "assistant";

                return (
                  <>
                    <Show when={msg.role === "user"}>
                      <UserBubble
                        msg={msg as { content: string | (TextContent | ImageContent)[] }}
                        timestamp={(msg as { timestamp: number }).timestamp}
                      />
                    </Show>
                    <Show when={msg.role === "assistant"}>
                      <AssistantBubble msg={msg as AssistantMessage} streaming={isStreamingMsg()} />
                    </Show>
                    <Show when={msg.role === "toolResult"}>
                      <ToolResultBubble msg={msg as ToolResultMessage} />
                    </Show>
                    <Show when={msg.role === "workflow"}>
                      <WorkflowCard msg={msg as WorkflowCardMessage} />
                    </Show>
                  </>
                );
              }}
            </For>

            <Show when={hasError()}>
              <div class="message--error mb-3 rounded-lg border border-danger/40 bg-danger/5 px-4 py-2 text-sm text-danger">
                {hasError()}
              </div>
            </Show>

            <div ref={messagesEndRef} />
          </div>
        </Show>
      </div>

      {/* ── Input ──────────────────────────────────── */}
      <div class="shrink-0 px-4 pb-4 pt-1">
        <div class="relative max-w-2xl mx-auto">
          <MentionPopup items={mentionItems()} onSelect={handleMentionSelect} />
          <div class="flex items-end gap-2 rounded-[22px] border border-border bg-panel p-2 shadow-lg">
            <textarea
              ref={textareaRef}
              class="flex-1 resize-none bg-transparent text-sm text-foreground placeholder:text-subtle px-2 py-1.5 min-h-[3rem] max-h-[12rem] leading-relaxed focus:outline-none"
              placeholder="Ask anything, @ to add files, / for commands"
              value={inputValue()}
              onInput={(e) => handleInput(e.currentTarget.value)}
              onKeyDown={handleKeyDown}
              disabled={isStreaming()}
              rows={1}
            />
            <button
              class={cn(
                "w-8 h-8 rounded-full flex items-center justify-center shrink-0 transition-colors text-sm font-medium",
                isStreaming()
                  ? "bg-danger text-white hover:bg-danger/80"
                  : inputValue().trim()
                    ? "bg-accent text-white hover:bg-accent/80"
                    : "bg-panel-2 text-subtle cursor-default",
              )}
              onClick={handleSend}
              title={isStreaming() ? "Stop" : "Send"}
            >
              {isStreaming() ? "■" : "Send"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
