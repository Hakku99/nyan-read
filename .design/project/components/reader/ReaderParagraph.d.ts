/** Reading-canvas paragraph: 2em indent, justified, pretty-wrapped. */
export interface ReaderParagraphProps {
  children?: any;
  /** Serif reading face. Default false (sans) */
  serif?: boolean;
  /** Default 18 */
  fontSize?: number;
  /** Default 1.75 */
  lineHeight?: number;
  /** Default var(--reader-ink) */
  color?: string;
}
export declare const ReaderParagraph: (props: ReaderParagraphProps) => any;
