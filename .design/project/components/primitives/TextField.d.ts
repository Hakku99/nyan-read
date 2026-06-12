/** Single- or multi-line text input. Optional label + leading icon, matcha focus ring, warm-clay error state. */
export interface TextFieldProps {
  value?: string;
  onChange?: (value: string) => void;
  /** Caption above the field */
  label?: string;
  placeholder?: string;
  /** Leading icon name */
  icon?: string;
  /** Render a <textarea> instead of <input> */
  multiline?: boolean;
  /** Rows when multiline. Default 3 */
  rows?: number;
  /** `true` for error ring only, or a string to also show the message */
  error?: boolean | string;
  disabled?: boolean;
  /** Fires on Enter (single-line only) */
  onSubmit?: (value: string) => void;
  style?: object;
}
export declare const TextField: (props: TextFieldProps) => any;
