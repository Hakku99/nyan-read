/** Shelf / in-book search input — controlled <input>, matcha focus ring, clear button. */
export interface SearchFieldProps {
  /** Current query string */
  value?: string;
  onChange?: (value: string) => void;
  /** Clear button handler; defaults to onChange("") */
  onClear?: () => void;
  /** Fires on Enter */
  onSubmit?: (value: string) => void;
  /** Default "Search title or author" */
  placeholder?: string;
  autoFocus?: boolean;
  style?: object;
}
export declare const SearchField: (props: SearchFieldProps) => any;
