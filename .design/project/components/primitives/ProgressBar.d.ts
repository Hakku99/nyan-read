/** The single reading-progress track — matcha fill on a tint trough. Replaces 5 inline copies. */
export interface ProgressBarProps {
  /** Progress 0–1 */
  value?: number;
  /** Track thickness in px. Default 3 (shelf); dock uses 4–6 */
  height?: number;
  /** Trailing caption: a string ("42%"), or `true` to auto-render the percent. Omit for no label */
  label?: string | boolean;
  /** Fill + label accent. Default var(--nyan-primary) */
  color?: string;
  style?: object;
}
export declare const ProgressBar: (props: ProgressBarProps) => any;
