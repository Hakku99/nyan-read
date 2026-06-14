/** Five-pen highlight colour picker (U5 / U2 / U13). Tokenised to --hl-* pens; selected pen gets a matcha ring. */
export interface HighlightPen {
  /** Stable id, e.g. "yellow" */
  id: string;
  /** CSS color (token preferred, e.g. var(--hl-yellow)) */
  color: string;
  /** Accessible label / tooltip */
  label?: string;
}
export interface HighlightSwatchRowProps {
  /** Defaults to the 5 --hl-* pens (yellow/green/blue/pink/orange) */
  pens?: HighlightPen[];
  /** Selected pen id or index */
  selected?: string | number;
  /** (id|index, pen) => void */
  onSelect?: (idOrIndex: string | number, pen: HighlightPen) => void;
  /** Swatch diameter in px. Default 22 */
  size?: number;
  /** Gap between swatches. Default 4 */
  gap?: number;
  style?: object;
}
export declare const HighlightSwatchRow: (props: HighlightSwatchRowProps) => any;
