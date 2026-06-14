/** Bookmark card: uppercase eyebrow, 2-line excerpt, optional divided Note pill + note text. */
export interface NyanBookmarkCardProps {
  /** Eyebrow, e.g. "Chapter 3 · 42%" */
  label: string;
  excerpt: string;
  note?: string;
  onPress?: () => void;
}
export declare const NyanBookmarkCard: (props: NyanBookmarkCardProps) => any;
