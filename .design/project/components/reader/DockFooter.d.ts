/** Persistent base of the One Paper dock: chapter stepper + progress, then the action row. */
export interface DockFooterProps {
  chapterIndex: number;
  chapterCount: number;
  /** 0-1 */
  progress: number;
  /** Key of the active action */
  activeAction?: string;
  onAction?: (key: string) => void;
  onPrevChapter?: () => void;
  onNextChapter?: () => void;
  /** Folds the stepper away while the sheet is grown */
  sheetOpen?: boolean;
  /** Defaults to Chapters / Bookmarks / Highlights / Settings */
  actions?: Array<{ key: string; icon: string; label: string }>;
  /** Localizable strings (English defaults). chapterStatus is (index, count) => string */
  labels?: {
    chapters?: string; bookmarks?: string; highlights?: string; settings?: string;
    prevChapter?: string; nextChapter?: string;
    chapterStatus?: (index: number, count: number) => string;
  };
}
export declare const DockFooter: (props: DockFooterProps) => any;
