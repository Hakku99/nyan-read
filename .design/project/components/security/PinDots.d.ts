/** Filled/empty PIN progress dots; shakes on error. dotColor adapts to the takeover theme. */
export interface PinDotsProps {
  /** Digits entered so far */
  count?: number;
  /** Total dots. Default 4 */
  length?: number;
  /** Trigger the shake + dim */
  hasError?: boolean;
  /** Dot + border colour (theme-adaptive). Default var(--nyan-text) */
  dotColor?: string;
  /** Gap between dots. Default 20 */
  gap?: number;
  /** Dot diameter. Default 16 */
  size?: number;
}
export declare const PinDots: (props: PinDotsProps) => any;
