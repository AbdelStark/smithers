import { type Component, Show, createSignal, createEffect } from "solid-js";
import { appState, setAppState, pushToast } from "../stores/app-store";
import { getRpc } from "../index";

interface SettingsDialogProps {
  modal?: boolean;
  open?: boolean;
  onClose?: () => void;
}

export const SettingsDialog: Component<SettingsDialogProps> = (props) => {
  const settings = () => appState.settings;

  const [panelOpen, setPanelOpen] = createSignal(
    settings()?.ui.workflowPanel.isOpen ?? true,
  );
  const [panelWidth, setPanelWidth] = createSignal(
    settings()?.ui.workflowPanel.width ?? 380,
  );
  const [provider, setProvider] = createSignal(
    settings()?.agent.provider ?? "openai",
  );
  const [model, setModel] = createSignal(
    settings()?.agent.model ?? "gpt-4o-mini",
  );
  const [temperature, setTemperature] = createSignal(
    settings()?.agent.temperature ?? 0.2,
  );
  const [maxTokens, setMaxTokens] = createSignal(
    settings()?.agent.maxTokens ?? 1024,
  );
  const [systemPrompt, setSystemPrompt] = createSignal(
    settings()?.agent.systemPrompt ?? "",
  );
  const [openaiKey, setOpenaiKey] = createSignal("");
  const [anthropicKey, setAnthropicKey] = createSignal("");
  const [allowNetwork, setAllowNetwork] = createSignal(
    settings()?.smithers?.allowNetwork ?? false,
  );

  createEffect(() => {
    const s = settings();
    if (!s) return;
    if (props.modal && !props.open) return;

    setPanelOpen(s.ui.workflowPanel.isOpen);
    setPanelWidth(s.ui.workflowPanel.width);
    setProvider(s.agent.provider as "openai" | "anthropic");
    setModel(s.agent.model);
    setTemperature(s.agent.temperature ?? 0.2);
    setMaxTokens(s.agent.maxTokens ?? 1024);
    setSystemPrompt(s.agent.systemPrompt ?? "");
    setAllowNetwork(s.smithers?.allowNetwork ?? false);
  });

  const handleClose = () => {
    if (props.onClose) props.onClose();
    else setAppState("currentView", "chat");
  };

  const save = async () => {
    const rpc = getRpc();
    const m =
      model().trim() ||
      (provider() === "anthropic" ? "claude-3-5-sonnet-20241022" : "gpt-4o-mini");
    const updated = await rpc.request.setSettings({
      patch: {
        ui: { workflowPanel: { isOpen: panelOpen(), width: panelWidth() } },
        agent: {
          provider: provider(),
          model: m,
          temperature: temperature(),
          maxTokens: maxTokens(),
          systemPrompt: systemPrompt(),
        },
        smithers: { allowNetwork: allowNetwork() },
      },
    });
    if (openaiKey().trim())
      await rpc.request.setSecret({
        key: "openai.apiKey",
        value: openaiKey().trim(),
      });
    if (anthropicKey().trim())
      await rpc.request.setSecret({
        key: "anthropic.apiKey",
        value: anthropicKey().trim(),
      });
    const secretStatus = await rpc.request.getSecretStatus({});
    setAppState({
      settings: updated,
      secretStatus,
      inspectorOpen: updated.ui.workflowPanel.isOpen,
    });
    pushToast("info", "Settings saved.");
    handleClose();
  };

  const clearOpenai = async () => {
    await getRpc().request.clearSecret({ key: "openai.apiKey" });
    const s = await getRpc().request.getSecretStatus({});
    setAppState("secretStatus", s);
    pushToast("info", "OpenAI API key cleared.");
  };

  const clearAnthropic = async () => {
    await getRpc().request.clearSecret({ key: "anthropic.apiKey" });
    const s = await getRpc().request.getSecretStatus({});
    setAppState("secretStatus", s);
    pushToast("info", "Anthropic API key cleared.");
  };

  const inputClass =
    "w-full bg-background border border-border text-foreground text-xs rounded-lg px-2 py-1.5 focus:border-accent focus:outline-none";
  const labelClass = "text-[10px] text-muted uppercase tracking-wide mt-2";
  const sectionClass =
    "text-[10px] font-semibold text-muted uppercase tracking-widest mt-4 mb-1";

  const content = (
    <div id="settings-panel-open" class="flex flex-col flex-1 min-h-0 overflow-y-auto p-4 max-w-lg mx-auto w-full">
      <h2 class="text-xs font-semibold uppercase tracking-wide mb-4">
        Preferences
      </h2>

      <div class={sectionClass}>UI</div>

      <label class={labelClass}>Inspector panel open</label>
      <select
        class={inputClass}
        value={panelOpen() ? "true" : "false"}
        onChange={(e) => setPanelOpen(e.currentTarget.value === "true")}
      >
        <option value="true">Open</option>
        <option value="false">Closed</option>
      </select>

      <label class={labelClass}>Inspector panel width</label>
      <input
        id="settings-panel-width"
        class={inputClass}
        type="number"
        value={panelWidth()}
        onInput={(e) => setPanelWidth(Number(e.currentTarget.value))}
      />

      <div class={sectionClass}>AI Provider</div>

      <label class={labelClass}>Provider</label>
      <select
        id="settings-provider"
        class={inputClass}
        value={provider()}
        onChange={(e) =>
          setProvider(e.currentTarget.value as "openai" | "anthropic")
        }
      >
        <option value="openai">OpenAI</option>
        <option value="anthropic">Anthropic</option>
      </select>

      <label class={labelClass}>Model</label>
      <input
        id="settings-model"
        class={inputClass}
        value={model()}
        onInput={(e) => setModel(e.currentTarget.value)}
      />

      <label class={labelClass}>Temperature</label>
      <input
        id="settings-temperature"
        class={inputClass}
        type="number"
        step="0.1"
        value={temperature()}
        onInput={(e) => setTemperature(Number(e.currentTarget.value))}
      />

      <label class={labelClass}>Max tokens</label>
      <input
        id="settings-max-tokens"
        class={inputClass}
        type="number"
        value={maxTokens()}
        onInput={(e) => setMaxTokens(Number(e.currentTarget.value))}
      />

      <label class={labelClass}>System prompt</label>
      <textarea
        id="settings-system-prompt"
        class={`${inputClass} font-mono min-h-[90px] resize-y`}
        value={systemPrompt()}
        onInput={(e) => setSystemPrompt(e.currentTarget.value)}
      />

      <div class={sectionClass}>API Keys</div>

      <label class={labelClass}>OpenAI API Key</label>
      <div class="flex gap-1.5">
        <input
          id="settings-openai-key"
          class={`${inputClass} flex-1`}
          type="password"
          placeholder={
            appState.secretStatus.openai ? "Configured" : "Not set"
          }
          value={openaiKey()}
          onInput={(e) => setOpenaiKey(e.currentTarget.value)}
        />
        <button
          id="settings-openai-clear"
          class="px-2 py-1 rounded border border-border bg-transparent text-muted text-[11px] uppercase cursor-pointer hover:text-foreground flex-shrink-0"
          onClick={clearOpenai}
        >
          Clear
        </button>
      </div>

      <label class={labelClass}>Anthropic API Key</label>
      <div class="flex gap-1.5">
        <input
          id="settings-anthropic-key"
          class={`${inputClass} flex-1`}
          type="password"
          placeholder={
            appState.secretStatus.anthropic ? "Configured" : "Not set"
          }
          value={anthropicKey()}
          onInput={(e) => setAnthropicKey(e.currentTarget.value)}
        />
        <button
          id="settings-anthropic-clear"
          class="px-2 py-1 rounded border border-border bg-transparent text-muted text-[11px] uppercase cursor-pointer hover:text-foreground flex-shrink-0"
          onClick={clearAnthropic}
        >
          Clear
        </button>
      </div>

      <div class={sectionClass}>Tools</div>

      <label class={labelClass}>Bash network access</label>
      <select
        id="settings-allow-network"
        class={inputClass}
        value={allowNetwork() ? "true" : "false"}
        onChange={(e) => setAllowNetwork(e.currentTarget.value === "true")}
      >
        <option value="false">Blocked</option>
        <option value="true">Allowed</option>
      </select>

      <div class="flex justify-end gap-1.5 mt-6">
        <button
          id="settings-cancel"
          class="px-3 py-1.5 rounded border border-border bg-transparent text-muted text-[11px] uppercase tracking-wide cursor-pointer hover:text-foreground"
          onClick={handleClose}
        >
          Cancel
        </button>
        <button
          id="settings-save"
          class="px-3 py-1.5 rounded bg-accent text-white text-[11px] font-semibold uppercase tracking-wide cursor-pointer"
          onClick={save}
        >
          Save
        </button>
      </div>
    </div>
  );

  if (props.modal) {
    return (
      <Show when={props.open}>
        <div
          class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50"
          onClick={() => handleClose()}
        >
          <div
            class="bg-panel border border-border rounded-xl w-[480px] max-h-[80vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            {content}
          </div>
        </div>
      </Show>
    );
  }

  return content;
};
