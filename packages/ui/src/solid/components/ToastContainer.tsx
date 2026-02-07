import { type Component, For } from "solid-js";
import { appState } from "../stores/app-store";
import { cn } from "../lib/utils";

export const ToastContainer: Component = () => {
  return (
    <div class="fixed bottom-4 right-4 z-50 flex flex-col gap-2" role="status" aria-live="polite">
      <For each={appState.toasts}>
        {(toast) => (
          <div
            class={cn(
              "toast px-4 py-3 rounded-md border bg-panel text-sm font-sans text-foreground shadow-lg max-w-xs",
              "animate-in slide-in-from-bottom-2 fade-in duration-200",
              `toast-${toast.level}`,
              toast.level === "info" && "border-l-[3px] border-l-accent border-border",
              toast.level === "warning" && "border-l-[3px] border-l-warning border-border",
              toast.level === "error" && "border-l-[3px] border-l-danger border-border"
            )}
          >
            {toast.message}
          </div>
        )}
      </For>
    </div>
  );
};
