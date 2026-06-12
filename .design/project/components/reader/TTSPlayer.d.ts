/** Read-aloud transport (U17), designed to drop inside a NyanBottomSheet. Header + scrubber + speed + play/skip. Fully controlled. */
export interface TTSPlayerProps {
  /** Default "Read Aloud" */
  title?: string;
  /** Chapter subtitle */
  chapter?: string;
  /** Voice chip label. Default "System Voice" */
  voice?: string;
  playing?: boolean;
  onTogglePlay?: () => void;
  onSkipBack?: () => void;
  onSkipForward?: () => void;
  /** Playback position 0–1 */
  progress?: number;
  onSeek?: (progress: number) => void;
  /** Elapsed time caption, e.g. "2:14" */
  elapsed?: string;
  /** Remaining/total caption, e.g. "7:30" */
  remaining?: string;
  /** Speed labels. Default ["0.75×","1.0×","1.25×","1.5×"] */
  speeds?: string[];
  /** Index of active speed. Default 1 */
  speedIndex?: number;
  onSpeed?: (index: number) => void;
  /** Tap the voice chip */
  onVoice?: () => void;
  style?: object;
}
export declare const TTSPlayer: (props: TTSPlayerProps) => any;
