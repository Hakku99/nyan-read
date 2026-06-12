/** List-view book row: small cover, title + author, inline progress, format chip, chevron. Pair with NyanRowGroup. */
export interface BookListRowProps {
  book: {
    title: string;
    author?: string;
    /** Format chip text, e.g. "EPUB" */
    fmt?: string;
    /** Progress 0–100 (preferred) */
    pct?: number;
    /** Progress 0–1 (alternative to pct) */
    progress?: number;
  };
  onPress?: () => void;
}
export declare const BookListRow: (props: BookListRowProps) => any;
