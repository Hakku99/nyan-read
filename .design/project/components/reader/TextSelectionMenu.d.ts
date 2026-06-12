/** Floating selection action bar (U5): labelled actions + divider + highlight pens. One Paper card, not Material grey. */
export interface TextSelectionAction {
  key: string;
  icon: string;
  label: string;
}
export interface TextSelectionMenuProps {
  /** Defaults to Copy + Search */
  actions?: TextSelectionAction[];
  onAction?: (key: string) => void;
  /** Selected highlight pen id/index */
  selectedPen?: string | number;
  onSelectPen?: (idOrIndex: string | number, pen: object) => void;
  /** Override the pen palette (defaults to the 5 --hl-* pens) */
  pens?: Array<{ id: string; color: string; label?: string }>;
  style?: object;
}
export declare const TextSelectionMenu: (props: TextSelectionMenuProps) => any;
