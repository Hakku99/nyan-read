/** Find-in-book header strip: back + SearchField + match stepper ("3 / 17" with ‹ ›). One Paper bar. */
export interface InBookSearchProps {
  value?: string;
  onChange?: (value: string) => void;
  /** Close the search bar */
  onClose?: () => void;
  /** Current match (0-based) */
  matchIndex?: number;
  /** Total matches; 0 hides the stepper */
  matchCount?: number;
  onPrevMatch?: () => void;
  onNextMatch?: () => void;
  style?: object;
}
export declare const InBookSearch: (props: InBookSearchProps) => any;
