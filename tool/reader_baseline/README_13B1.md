# 13B-1 short comparison

Freeze the existing rendering candidate before changing it:

```powershell
python tool/reader_baseline/prepare_13b1.py --freeze --variant A
```

The frozen base includes `dd2c6b1` (EPUB image positioning) and the two existing
working-tree rendering files. Both variants must share ReaderPage and all
engine files; only SmoothPageReader may differ. Preserve this output directory
when resuming, rather than freezing a different baseline under the same name.

After applying one candidate:

```powershell
./tool/reader_baseline/build_13b1.ps1 -Variant A
./tool/reader_baseline/build_13b1.ps1 -Variant B
python tool/reader_baseline/run_13b1.py --prefix foreground-13b1
python tool/reader_baseline/analyze_13a.py .dart_tool/perf13b1/results --target-capture-variants A B
python tool/reader_baseline/summarize_13a.py .dart_tool/perf13b1/analysis.json
```

Use the target-capture policy explicitly: both 13B-1 variants retain the target
snapshot, unlike the historical 13A experiment. The analyzer still requires
exactly one target capture and released resources for every completed turn.
Do not rewrite original JSON to make it pass the older variant policy.

The matrix is two short AB/BA pairs, three full-app scenes (TXT long, EPUB long,
EPUB image), two first-path and twelve warm turns per scene/version/round.
First-path follows initial page readiness; it is not fully cold disk/image/GPU.
The last scene order reverses for both variants in the second pair.
Keep the emulator foreground; do not build, test or run heavy tracing alongside
measurements. No endurance run is included. Reuse the dedicated diagnostic app
ID, never the normal installation; original 13A host evidence is preserved.

Compare per-round slow-frame counts, stages, first-motion and completion times,
positions, layer/picture cache bytes and RSS samples. A smaller percentage with
more total frames is not sufficient evidence. Keep a candidate only when its
benefit survives both run orders without correctness or resource regression.
Short emulator results do not establish commercial release readiness.

The first candidate was rejected and production restored to its frozen source.
Its copy remains under `.dart_tool/perf13b1/rejected/lib/modules/reader/widgets/`.
Use `build_13b1.ps1 -Variant B -CandidateFile <preserved smooth_page_reader.dart>`
to replay it without reintroducing it into production. Preparation rejects an
identical A/B source. Source manifests and APKs from the experiment remain intact.

The second pair needed fresh installation after an insufficient-storage error.
The runner now removes only the dedicated test package, verifies its absence,
and tells the shared runner not to clear a nonexistent installation. Completed
host evidence is retained. Use a new prefix and `--start-pair 2` to resume only
the second pair; never overwrite an earlier setup failure or successful run.

## Covered-page investigation

The follow-up uses `.dart_tool/perf13b1_occlusion`, preserving the rejected
boundary experiment. Pass `--output` to preparation/runner and
`-OutputDirectory` to the builder. Build variants **sequentially**: the generated
project is shared, and preparation replaces its source files.

```powershell
python tool/reader_baseline/prepare_13b1.py --freeze --variant A --output .dart_tool/perf13b1_occlusion
./tool/reader_baseline/build_13b1.ps1 -Variant A -OutputDirectory .dart_tool/perf13b1_occlusion
./tool/reader_baseline/build_13b1.ps1 -Variant B -OutputDirectory .dart_tool/perf13b1_occlusion
python tool/reader_baseline/run_13b1.py --prefix foreground-occlusion --output .dart_tool/perf13b1_occlusion --turns 4 --input-checks
python tool/reader_baseline/analyze_13a.py .dart_tool/perf13b1_occlusion/results --target-capture-variants A B
```

This short matrix uses two first-path and four warm turns per scene/version/
round. Input checks run equally in both variants of the first pair, outside
timed samples. They cover body swipe, rapid taps, mode and overlay cancellation.
Do not mix these small samples with the earlier twelve-turn matrix or interpret
them as endurance/device acceptance.

`inspect_buffer_waits.py` reuses an existing heavy trace and joins **all**
measured frames (including fast frames) to raster thread slices/states. It
converts the recorded monotonic clock using trace clock snapshots. Pass the
heavy-run directory, `--output <new analysis directory>` and
`--processor .dart_tool/perf13a/trace_processor.py`. This does not collect another
trace or modify the original evidence. Wait duration identifies producer
backpressure, not its ultimate GPU/compositor cause.

## Buffer-chain follow-up and duplicate-frame fix

Use `buffer_chain.sql` with the local trace processor to export slices from
each original heavy trace separately. Also export the clock conversion with
`SELECT AVG(ts-clock_value) AS offset_ns FROM clock_snapshot WHERE clock_name='MONOTONIC';`.
Then run:

```powershell
python tool/reader_baseline/analyze_buffer_chain.py <heavy-run-directory> --slices <chain.csv> --offset <offset.csv> --output <analysis.json>
python -m unittest discover -s tool/reader_baseline -p 'test_*.py'
```

The analyzer accepts exactly one reader SurfaceView. It uses buffer numbers from
BLAST acquire/release and SurfaceFlinger latch/release events, not Flutter frame
numbers or FenceMonitor counters. Missing/ambiguous chains are rejected, and a
release starting after the wait is never used to explain that wait. `submit`
denotes BLAST's observed consumer acquisition during queueing, not the exact
start of the producer's queueBuffer call. HWC present duration is an API duration,
not touch-to-photon latency or pure GPU execution time.

The duplicate-frame follow-up is in `.dart_tool/perf13b1_buffers`. Its A APK is
reused from the preceding frozen baseline only after checking every generated
Dart source hash and the base commit. B changes only the private capture wait.
The incoming-capture marker accepts both policies and rejects unknown call forms.

```powershell
python tool/reader_baseline/run_13b1.py --prefix foreground-buffer --output .dart_tool/perf13b1_buffers --pairs 1 --scenes txt_long epub_image --turns 4 --input-checks
python tool/reader_baseline/analyze_13a.py .dart_tool/perf13b1_buffers/results --target-capture-variants A B
```

This deliberately small check establishes elimination of one redundant preparation
frame, fresh target pixels and unchanged navigation/input behavior. It does not
meet the multi-round criterion for accepting an overall slow-frame improvement.
Keep the local fix and overall item 13 performance acceptance separate.
