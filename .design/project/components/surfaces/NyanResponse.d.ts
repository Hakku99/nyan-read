/** The single shared feedback toast: success / error / skipped / info / loading, optional ghost action. */
export interface NyanResponseProps {
  /** Default "success" */
  status?: "success" | "error" | "skipped" | "info" | "loading";
  /** Short Title-Case line, e.g. "Bookmark deleted" */
  title: string;
  description?: string;
  /** One trailing ghost action (e.g. Undo) */
  action?: { label: string; onPress?: () => void };
  /** Shows a quiet close button; omit for auto-dismiss toasts */
  onDismiss?: () => void;
  /** "bottom" floats inset at base of a relative parent | "static" inline. Default "static" */
  placement?: "bottom" | "static";
  style?: object;
}
export declare const NyanResponse: (props: NyanResponseProps) => any;
