/** Square multi-select control. Checked = matcha fill + cream tick; 44px tap target, 22px box. */
export interface CheckboxProps {
  checked?: boolean;
  onChange?: (next: boolean) => void;
  disabled?: boolean;
  /** Visible box size in px. Default 22 */
  size?: number;
  /** Accessible name (role="checkbox") */
  "aria-label"?: string;
}
export declare const Checkbox: (props: CheckboxProps) => any;
