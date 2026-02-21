import React from "react";
import { WORKTREE_EMPTY_PATH_ERROR } from "../constants";

export type WorktreeProps = {
  id?: string;
  path: string;
  branch?: string;
  skipIf?: boolean;
  children?: React.ReactNode;
};

export function Worktree(props: WorktreeProps) {
  if (typeof props.path !== "string" || props.path.trim() === "") {
    throw new Error(WORKTREE_EMPTY_PATH_ERROR);
  }
  if (props.skipIf) return null;
  const next: { id?: string; path: string; branch?: string } = { id: props.id, path: props.path, branch: props.branch };
  return React.createElement("smithers:worktree", next, props.children);
}
