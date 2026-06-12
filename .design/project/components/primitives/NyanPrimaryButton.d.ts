/** Matcha CTA button. Heights are locked per size (sm 36 / md 44 / lg 52); label is single-line ellipsis. */
export interface NyanPrimaryButtonProps {
  label: string;
  onPress?: () => void;
  /** Icon name rendered before the label */
  icon?: string;
  /** Stretch to 100% width. Default false */
  expanded?: boolean;
  /** "primary" matcha fill | "deep" darker fill | "ghost" transparent w/ deep text. Default "primary" */
  variant?: "primary" | "deep" | "ghost";
  /** sm 36px (in-card) | md 44px (default, = min tap target) | lg 52px (hero) */
  size?: "sm" | "md" | "lg";
  /** Dim to 40%, block onPress */
  disabled?: boolean;
  /** Swap the icon for a spinner, block onPress, set aria-busy */
  loading?: boolean;
  style?: object;
}
export declare const NyanPrimaryButton: (props: NyanPrimaryButtonProps) => any;
