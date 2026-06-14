/** Centered confirm / alert dialog — warm-ink scrim, --r-panel card, optional icon tile + up to two actions. */
export interface NyanDialogProps {
  open: boolean;
  /** Scrim-tap dismiss */
  onClose?: () => void;
  /** Tinted icon tile glyph */
  icon?: string;
  title: string;
  message?: string;
  /** "default" matcha | "danger" warm-clay error tones */
  tone?: "default" | "danger";
  /** Default "Confirm" */
  confirmLabel?: string;
  /** Default "Cancel" */
  cancelLabel?: string;
  onConfirm?: () => void;
  /** Defaults to onClose */
  onCancel?: () => void;
  /** Single-action dialog (alert) */
  hideCancel?: boolean;
  /** Extra body content between message and actions (e.g. a TextField for rename) */
  children?: any;
}
export declare const NyanDialog: (props: NyanDialogProps) => any;
