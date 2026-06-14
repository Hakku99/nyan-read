/** Numeric PIN keypad — 72px round keys, backspace bottom-right. keyColor adapts to the takeover theme. */
export interface PinPadProps {
  onDigit?: (digit: number) => void;
  onDelete?: () => void;
  /** Key text + tint colour (theme-adaptive). Default var(--nyan-text) */
  keyColor?: string;
  /** Key diameter. Default 72 */
  keySize?: number;
  /** Gap between keys. Default 16 */
  gap?: number;
}
export declare const PinPad: (props: PinPadProps) => any;
