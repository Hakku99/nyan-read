# Item 13A diagnostic workflow

This tooling builds a disposable Android profile application with application ID
`com.example.nyan_read.perf13a`. It does not modify production reader sources or
open the normal application's database. It requires the pinned `ae5a630` commit,
the item 13 working-tree candidate, Flutter 3.38.9, the Android SDK and Python.

## Prepare and verify

Run from the repository root:

```powershell
python tool/reader_baseline/prepare_13a.py --freeze --variant A
./tool/reader_baseline/build_13a.ps1 -Variant A
./tool/reader_baseline/build_13a.ps1 -Variant B
python tool/reader_baseline/run_13a.py --setup --mode pilot --variant A --prefix pilot
python tool/reader_baseline/run_13a.py --mode pilot --variant B --prefix pilot
python tool/reader_baseline/analyze_13a.py .dart_tool/perf13a/results
```

`--freeze` is one-time for this output directory. The manifest pins the base,
candidate patch and source hashes; preparation fails on drift. The generated
source differences must be restricted to `reader_page.dart`,
`smooth_page_reader.dart`, and the harness's PDF target-capture flag. The same
stage probes are injected into both versions. The final APKs must differ and
their compiled variant must match the runtime configuration. Explicit build
defines invalidate stale Gradle/AOT artifacts; a successful build exit code is
not enough to establish that the candidate was compiled.

The sample directory defaults to the user's `Downloads/Mobile Devices` and can
be overridden with `--samples`. `--adb` overrides the SDK executable. The runner
selects the authorized samples by their recorded byte sizes and stores hashes.
Only the runner's copied EPUB is temporarily removed during APK replacement to
leave sufficient free space on small emulator partitions. It is copied back
before launch. Originals and the normal application are untouched.

## Measurement

Keep the emulator visible and foreground throughout a batch. Window occlusion
substantially changed raster timing in calibration. Do not mix foreground and
background-window measurements, or build/test concurrently with measurement.

```powershell
python tool/reader_baseline/run_13a.py --mode matrix --prefix foreground
python tool/reader_baseline/run_13a.py --mode overhead --prefix foreground
python tool/reader_baseline/run_13a.py --mode full --prefix foreground
python tool/reader_baseline/run_13a.py --mode stress --variant B --full-app --prefix foreground
python tool/reader_baseline/analyze_13a.py .dart_tool/perf13a/results
python tool/reader_baseline/summarize_13a.py .dart_tool/perf13a/analysis.json
python tool/reader_baseline/report_13a.py .dart_tool/perf13a/results
python -m unittest discover -s tool/reader_baseline -p test_analyze_13a.py
```

Each invocation needs a new prefix if that run already exists. A process begins
with a fresh engine and uses identical reset/warmup/forward/back trajectories.
`first` means the first turn pair in that scene, after initial layout readiness;
it is not a claim that disk, driver, or all image caches are cold. Only the first
scene in a process is process-cold. `warm` is the subsequent 12-turn pair.
PDF is a synthetic text fixture, not the user's document. Full-app results are
separate from the engine/container matrix. `stress` lasts at least 20 minutes,
with bounded batches and exports between batches.

Stress runs pull new blocks incrementally and retain a host checkpoint. Files
are validated as JSON before atomic local promotion; final export remains
necessary after interruption. Incomplete runs never enter the performance
matrix. The November 4 delivery stopped endurance testing at the user's request:
`resource-validation.json` records the explicit exception, and `partialStress`
contains observations only. Do not combine separate runs into continuous time
or interpret packaging as resource acceptance. Empty interrupted files remain
listed in the evidence and excluded from numerical summaries.

Raw frame timestamps and paint-state frame IDs are retained. The analyzer
requires paint marks to lie inside their corresponding UI build interval before
joining clocks. It preserves cross-stage frames and validates target-capture
presence and cleared snapshot references. `motionFirst` and `motionLast` are
the first/last 10% of controller time, not claims about physical screen present.
An image dispose call does not prove synchronous GPU resource release.

The trace-disabled overhead control retains the common FrameTiming collector
and request latency sampling, disabling the additional phase/paint probes. Thus
it measures their incremental overhead, not the total cost of all diagnostics.
Heavy Flutter/system tracing must run separately from the lightweight matrix.

## Separate functional and heavy traces

```powershell
python tool/reader_baseline/run_13a.py --mode heavy --variant A --prefix foreground-heavy --scenes txt_long epub_long epub_image
python tool/reader_baseline/run_13a.py --mode heavy --variant B --prefix foreground-heavy --scenes txt_long epub_long epub_image
python tool/reader_baseline/run_13a.py --mode heavy --variant B --full-app --prefix foreground-apptrace --scenes txt_long epub_long epub_image
./tool/reader_baseline/build_13a.ps1 -Variant A -InputAudit
./tool/reader_baseline/build_13a.ps1 -Variant B -InputAudit
python tool/reader_baseline/run_13a.py --mode input --variant A --prefix foreground-audit
python tool/reader_baseline/run_13a.py --mode input --variant B --prefix foreground-audit
```

The supplemental APKs add input disposition and image-layout records only in
the disposable project. Existing functional assertions remain intact. A failed
image assertion is saved as a failed run, not silently turned into a pass.
Full-app performance runs omit this separate functional probe so the two kinds
of evidence remain distinguishable. Full-app taps use Flutter pointer injection
through hit testing, not physical touch-to-display latency measurement.

The retained `foreground-audit` v1 runs measured the ancestor viewport in their
`height` field, and closed trace IDs before late cancellation cleanup. Do not
use those fields as image-height or resource-release evidence. The separate
`foreground-imagecheck` runs correct the local context and retain the trace ID
through cleanup; their APK/source manifests are distinct. Original assertions
and failures remain available in both versions.

Heavy capture saves local `flutter-timeline.json` and `system.pftrace`, using
the VM service and the emulator's normal Perfetto support. It requires no root
access or external upload. Use the official Perfetto trace processor locally;
retain its version and queries with the results. Clock correlation must be
verified before combining system and Flutter timestamps.

Start the VM recorder before Perfetto: Flutter automatically forwards its
timeline to ATrace if ATrace is already enabled at engine startup. The runner
uses the supported `trace-startup` switch and then starts a 128MB system buffer.
The earlier 32MB system capture overwrote events and is retained only as limited
diagnostic evidence. Inspect `stats` for loss/overwrites before using any trace.

```powershell
python tool/reader_baseline/analyze_13a_timeline.py .dart_tool/perf13a/results/foreground-apptrace-heavy-B
python .dart_tool/perf13a/trace_processor.py query --format csv -f tool/reader_baseline/perf13a_system.sql .dart_tool/perf13a/results/foreground-apptrace-heavy-B/system.pftrace
python tool/reader_baseline/correlate_13a_system.py .dart_tool/perf13a/results/foreground-apptrace-heavy-B --processor .dart_tool/perf13a/trace_processor.py
```

The system join uses clock snapshots, not an assumed shared epoch. VM span
matching must exclude the next raster frame even when it starts immediately
after the current one. Completion can reveal the body within a frame that
started before release; the actual paint-state marker determines that phase.

Outputs and generated source trees live under `.dart_tool/perf13a/`. Runtime
errors, incomplete runs, buffer overflow and timing mismatches must remain
visible and must not be included as successful samples. Export includes only
numeric positions, frame data and generic fixture identifiers, never book text.
Remove the dedicated test application only after pulling all required results.
