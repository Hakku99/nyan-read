/** Base paper card. "standard" = radius-card + light shadow; "grouped" = radius-input + grouped shadow. */
export interface NyanInfoCardProps {
  children?: any;
  variant?: "standard" | "grouped";
  /** Surface tone. Default "surface" */
  tone?: "surface" | "muted" | "raised";
  /** CSS padding. Default 16 */
  padding?: number | string;
  onPress?: () => void;
  style?: object;
}
export declare const NyanInfoCard: (props: NyanInfoCardProps) => any;
