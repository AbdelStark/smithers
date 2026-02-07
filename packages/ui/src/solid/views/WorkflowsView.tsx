import { type Component, For, Show } from "solid-js";
import { appState } from "../stores/app-store";

export const WorkflowsView: Component<{ onRunWorkflow?: (preselect?: string) => void }> = (props) => {
  return (
    <div class="flex flex-col flex-1 min-h-0 overflow-hidden">
      <div class="px-4 py-3 border-b border-border">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-muted">
          Workflows
        </h3>
      </div>
      <div class="flex-1 overflow-y-auto">
        <Show
          when={appState.workflows.length > 0}
          fallback={
            <div class="empty text-muted text-xs uppercase tracking-wide text-center py-8">
              No workflows found. Open a workspace to scan for .tsx workflows.
            </div>
          }
        >
          <For each={appState.workflows}>
            {(wf) => (
              <div class="workflow-row flex items-center justify-between px-4 py-3 border-b border-border hover:bg-panel-2 transition-colors">
                <div>
                  <div class="workflow-row__title font-semibold text-sm">{wf.name ?? wf.path}</div>
                  <div class="text-[10px] text-muted mt-0.5">{wf.path}</div>
                </div>
                <button
                  class="px-3 py-1.5 rounded bg-accent text-white text-[11px] font-semibold uppercase tracking-wide cursor-pointer hover:bg-accent-hover"
                  onClick={() => props.onRunWorkflow?.(wf.path)}
                >
                  Run
                </button>
              </div>
            )}
          </For>
        </Show>
      </div>
    </div>
  );
};
