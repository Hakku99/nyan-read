/** Chapter list; current chapter gets matcha badge, deep title, play glyph. */
export interface ReaderChapterListProps {
  chapters: string[];
  currentIndex: number;
  /** Default true */
  ascending?: boolean;
  onSelect?: (index: number) => void;
}
export declare const ReaderChapterList: (props: ReaderChapterListProps) => any;
