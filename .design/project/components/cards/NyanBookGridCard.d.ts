/** Chromeless shelf grid card: 120:156 cover wash, format chip, progress bar once started, 2-line title. */
export interface NyanBookGridCardProps {
  book: {
    title: string;
    author?: string;
    /** Format chip text, e.g. "EPUB" */
    fmt?: string;
    /** Progress 0-100 (preferred) */
    pct?: number;
    /** Progress 0-1 (alternative to pct) */
    progress?: number;
  };
  /** Selected ring + check (multi-select) */
  selected?: boolean;
  /** Show the top-left selection check */
  selectionMode?: boolean;
  onPress?: () => void;
  /** Fires after a 400ms hold */
  onLongPress?: () => void;
}
export declare const NyanBookGridCard: (props: NyanBookGridCardProps) => any;
