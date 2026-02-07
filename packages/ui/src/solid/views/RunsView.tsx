import { type Component, For, Show } from "solid-js";
import { appState, pushToast } from "../stores/app-store";
import { focusRun, getRpc, refreshRuns } from "../index";
import { formatTime, formatDuration } from "../lib/format";
import { cn } from "../lib/utils";

function statusColor(status: string): string {
  switch (status) {
    case "running":
      return "bg-accent";
    case "finished":
      return "bg-success";
    case "failed":
      return "bg-danger";
    case "waiting-approval":
      return "bg-warning";
    case "cancelled":
      return "bg-subtle";
    default:
      return "bg-subtle";
  }
}

const btnClass =
  "px-2 py-1 rounded border border-border bg-panel-2 text-muted text-[11px] uppercase tracking-wide cursor-pointer hover:text-foreground";

export const RunsView: Component = () => {
  return (
    <div class="flex flex-col flex-1 min-h-0 overflow-hidden">
      <div class="px-4 py-3 border-b border-border">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-muted">
          Runs
        </h3>
      </div>
      <div class="flex-1 overflow-y-auto">
        <Show
          when={appState.runs.length > 0}
          fallback={
            <div class="empty text-muted text-xs uppercase tracking-wide text-center py-8">
              No runs found.
            </div>
          }
        >
          <For each={appState.runs}>
            {(run) => (
              <div
                class={cn("run-row flex items-center gap-3 px-4 py-3 border-b border-border cursor-pointer hover:bg-panel-2 transition-colors", `status-${run.status}`)}
                onClick={() => focusRun(run.runId)}
                tabIndex={0}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    focusRun(run.runId);
                  }
                }}
                role="listitem"
              >
                <div
                  class={cn(
                    "w-2 h-2 rounded-full flex-shrink-0",
                    statusColor(run.status),
                  )}
                />
                <div class="flex-1 min-w-0">
                  <div class="font-semibold text-sm truncate">
                    {run.workflowName}
                  </div>
                  <div class="text-[10px] text-muted flex flex-wrap gap-1 mt-0.5">
                    <span class="font-mono">{run.runId.slice(0, 6)}</span>
                    <span>• {formatTime(run.startedAtMs)}</span>
                    <span>
                      • {formatDuration(run.startedAtMs, run.finishedAtMs ?? null)}
                    </span>
                    <Show when={run.activeNodes?.length}>
                      <span>
                        • Active:{" "}
                        <span class="font-mono">{run.activeNodes![0]}</span>
                      </span>
                    </Show>
                    <Show when={(run.waitingApprovals ?? 0) > 0}>
                      <span class="bg-accent text-[#07080A] text-[9px] px-1.5 rounded-full font-semibold">
                        {run.waitingApprovals} approvals
                      </span>
                    </Show>
                  </div>
                </div>
                <div
                  class="flex gap-1 flex-shrink-0"
                  onClick={(e) => e.stopPropagation()}
                >
                  <button
                    class={btnClass}
                    data-action="open"
                    onClick={() => focusRun(run.runId)}
                  >
                    Open
                  </button>
                  <Show when={run.status === "running" || run.status === "waiting-approval"}>
                    <button
                      class={btnClass}
                      data-action="cancel"
                      onClick={async () => {
                        await getRpc().request.cancelRun({ runId: run.runId });
                        await refreshRuns();
                        pushToast("info", "Run cancelled");
                      }}
                    >
                      Cancel
                    </button>
                  </Show>
                  <Show when={run.status === "waiting-approval"}>
                    <button
                      class={btnClass}
                      data-action="resume"
                      onClick={() =>
                        getRpc().request.resumeRun({ runId: run.runId })
                      }
                    >
                      Resume
                    </button>
                  </Show>
                  <button
                    class={btnClass}
                    data-action="copy"
                    onClick={() => {
                      navigator.clipboard?.writeText(run.runId);
                      pushToast("info", "Run ID copied");
                    }}
                  >
                    Copy ID
                  </button>
                </div>
              </div>
            )}
          </For>
        </Show>
      </div>
    </div>
  );
};
