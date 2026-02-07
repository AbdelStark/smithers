import { type Component, For, Show, createSignal, onCleanup, onMount } from "solid-js";

interface MenubarProps {
  onOpenWorkspace: () => void;
  onCloseWorkspace: () => void;
  onRunWorkflow: () => void;
  onPreferences: () => void;
  onDocs: () => void;
  onZoomIn: () => void;
}

type MenuItem = { label: string; action: () => void };
type MenuDef = { key: string; label: string; items: MenuItem[] };

export const Menubar: Component<MenubarProps> = (props) => {
  const [openMenu, setOpenMenu] = createSignal<string | null>(null);

  const menus: MenuDef[] = [
    {
      key: "file",
      label: "File",
      items: [
        { label: "Open Workspace", action: () => { close(); props.onOpenWorkspace(); } },
        { label: "Close Workspace", action: () => { close(); props.onCloseWorkspace(); } },
      ],
    },
    {
      key: "workflow",
      label: "Workflow",
      items: [
        { label: "Run Workflow", action: () => { close(); props.onRunWorkflow(); } },
      ],
    },
    {
      key: "view",
      label: "View",
      items: [
        { label: "Zoom In", action: () => { close(); props.onZoomIn(); } },
      ],
    },
    {
      key: "settings",
      label: "Settings",
      items: [
        { label: "Preferences", action: () => { close(); props.onPreferences(); } },
      ],
    },
    {
      key: "help",
      label: "Help",
      items: [
        { label: "Docs", action: () => { close(); props.onDocs(); } },
      ],
    },
  ];

  const close = () => setOpenMenu(null);

  const handleClickOutside = (e: MouseEvent) => {
    const target = e.target as HTMLElement;
    if (!target.closest(".menubar")) close();
  };

  onMount(() => document.addEventListener("click", handleClickOutside));
  onCleanup(() => document.removeEventListener("click", handleClickOutside));

  return (
    <div class="menubar flex items-center bg-[#07080A] border-b border-border h-7 px-2 gap-0 text-xs shrink-0 relative z-30">
      <For each={menus}>
        {(menu) => (
          <div class="relative">
            <button
              class="menu-item px-2 py-1 text-muted hover:text-foreground bg-transparent border-none cursor-pointer text-xs"
              data-menu={menu.key}
              onClick={(e) => {
                e.stopPropagation();
                setOpenMenu((v) => (v === menu.key ? null : menu.key));
              }}
            >
              {menu.label}
            </button>
            <div
              class="menu-dropdown absolute top-full left-0 bg-panel border border-border rounded shadow-lg min-w-[160px] py-1 z-40"
              classList={{ hidden: openMenu() !== menu.key }}
            >
              <For each={menu.items}>
                {(item) => (
                  <button
                    class="menu-row w-full text-left px-3 py-1.5 text-xs text-foreground hover:bg-panel-2 bg-transparent border-none cursor-pointer"
                    onClick={(e) => {
                      e.stopPropagation();
                      item.action();
                    }}
                  >
                    {item.label}
                  </button>
                )}
              </For>
            </div>
          </div>
        )}
      </For>

      <div class="flex-1" />

      <button
        id="run-workflow"
        class="px-2 py-0.5 text-[10px] text-muted hover:text-foreground bg-transparent border border-border rounded cursor-pointer"
        onClick={() => props.onRunWorkflow()}
      >
        Run
      </button>
    </div>
  );
};
