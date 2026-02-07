import { type Component, For, Show, createSignal, createEffect } from "solid-js";
import { appState, pushToast } from "../stores/app-store";
import { getRpc, refreshRuns, focusRun } from "../index";

interface RunDialogProps {
  open: boolean;
  onClose: () => void;
  preselect?: string;
}

export const RunDialog: Component<RunDialogProps> = (props) => {
  const [selectedPath, setSelectedPath] = createSignal("");
  const [inputJson, setInputJson] = createSignal("{}");

  createEffect(() => {
    if (props.open) {
      const pre = props.preselect ?? appState.workflows[0]?.path ?? "";
      setSelectedPath(pre);
      setInputJson("{}");
    }
  });

  const runWorkflow = async () => {
    const path = selectedPath();
    if (!path) {
      pushToast("warning", "No workflow selected.");
      return;
    }
    let input: Record<string, unknown> = {};
    try {
      input = JSON.parse(inputJson());
    } catch {
      input = {};
    }
    const run = await getRpc().request.runWorkflow({
      workflowPath: path,
      input,
      attachToSessionId: appState.sessionId || undefined,
    });
    props.onClose();
    await refreshRuns();
    await focusRun(run.runId);
  };

  return (
    <Show when={props.open}>
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50"
        onClick={() => props.onClose()}
      >
        <div
          class="bg-panel border border-border rounded-xl p-4 w-[420px] flex flex-col gap-2 max-h-[80vh] overflow-y-auto"
          onClick={(e) => e.stopPropagation()}
        >
          <h2 class="text-xs font-semibold uppercase tracking-wide">Run Workflow</h2>

          <label class="text-[10px] text-muted uppercase tracking-wide">Workflow</label>
          <select
            id="workflow-select"
            class="bg-background border border-border text-foreground text-xs rounded-lg px-2 py-1.5 focus:border-accent focus:outline-none"
            value={selectedPath()}
            onChange={(e) => setSelectedPath(e.currentTarget.value)}
          >
            <For each={appState.workflows}>
              {(wf) => <option value={wf.path}>{wf.name ?? wf.path}</option>}
            </For>
          </select>

          <label class="text-[10px] text-muted uppercase tracking-wide">Input (JSON)</label>
          <textarea
            id="workflow-input"
            class="bg-background border border-border text-foreground text-xs rounded-lg px-2 py-1.5 font-mono min-h-[90px] resize-y focus:border-accent focus:outline-none"
            value={inputJson()}
            onInput={(e) => setInputJson(e.currentTarget.value)}
          />

          <div class="flex justify-end gap-1.5 mt-2">
            <button
              id="modal-cancel"
              class="px-3 py-1.5 rounded border border-border bg-transparent text-muted text-[11px] uppercase tracking-wide cursor-pointer hover:text-foreground"
              onClick={() => props.onClose()}
            >
              Cancel
            </button>
            <button
              id="modal-run"
              class="px-3 py-1.5 rounded bg-accent text-white text-[11px] font-semibold uppercase tracking-wide cursor-pointer"
              onClick={runWorkflow}
            >
              Run
            </button>
          </div>
        </div>
      </div>
    </Show>
  );
};
