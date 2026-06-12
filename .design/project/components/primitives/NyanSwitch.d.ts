/** Toggle switch, matcha-tinted. */
export interface NyanSwitchProps {
  /** Disable interaction and dim to 40% */
  disabled?: boolean;
  /** Accessible name (rendered as aria-label on the switch) */
  "aria-label"?: string;
  value: boolean;
  onChange: (next: boolean) => void;
}
export declare const NyanSwitch: (props: NyanSwitchProps) => any;
