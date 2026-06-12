/** Option chip — outline-on-select signature. Resting: muted fill; selected: matcha-deep outline + text, no fill. */
export interface PillButtonProps {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  icon?: string;
  /** Dim to 40%, block onPress */
  disabled?: boolean;
  style?: object;
}
export declare const PillButton: (props: PillButtonProps) => any;
