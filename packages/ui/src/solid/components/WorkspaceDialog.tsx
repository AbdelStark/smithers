import { type Component, Show, createSignal, createEffect } from "solid-js";
import { setAppState, pushToast } from "../stores/app-store";
import { getRpc, refreshRuns } from "../index";

interface WorkspaceDialogProps {
  open: boolean;
  onClose: () => void;
}

export const WorkspaceDialog: Component<WorkspaceDialogProps> = (props) => {
  const [path, setPath] = createSignal("");

  createEffect(() => {
    if (props.open) setPath("");
  });

  const handleOpen = async () => {
    const p = path().trim();
    if (!p) return;
    try {
      await getRpc().request.openWorkspace({ path: p });
      const ws = await getRpc().request.getWorkspaceState({});
      setAppState({ workspaceRoot: ws.root, workflows: ws.workflows });
      await refreshRuns();
      props.onClose();
    } catch (e: any) {
      pushToast("error", `Failed to open workspace: ${e?.message ?? e}`);
    }
  };

  return (
    <Show when={props.open}>
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50"
        onClick={() => props.onClose()}
      >
        <div
          class="bg-panel border border-border rounded-xl p-4 w-[420px] flex flex-col gap-3"
          onClick={(e) => e.stopPropagation()}
        >
          <h2 class="text-xs font-semibold uppercase tracking-wide">Open Workspace</h2>
          <input
            id="workspace-path"
            class="w-full bg-background border border-border text-foreground text-xs rounded-lg px-2 py-1.5 focus:border-accent focus:outline-none"
            placeholder="Enter workspace path…"
            value={path()}
            onInput={(e) => setPath(e.currentTarget.value)}
            onKeyDown={(e) => { if (e.key === "Enter") handleOpen(); }}
          />
          <div class="flex justify-end gap-1.5">
            <button
              id="workspace-cancel"
              class="px-3 py-1.5 rounded border border-border bg-transparent text-muted text-[11px] uppercase tracking-wide cursor-pointer hover:text-foreground"
              onClick={() => props.onClose()}
            >
              Cancel
            </button>
            <button
              id="workspace-open"
              class="px-3 py-1.5 rounded bg-accent text-white text-[11px] font-semibold uppercase tracking-wide cursor-pointer"
              onClick={handleOpen}
            >
              Open
            </button>
          </div>
        </div>
      </div>
    </Show>
  );
};
