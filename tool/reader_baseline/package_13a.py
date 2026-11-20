"""Package numerical evidence locally; never include books, fonts or APKs."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.dart_tool/perf13a'


def read(name):
    return json.loads((OUT / name).read_text(encoding='utf-8-sig'))


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    analysis, evidence = read('analysis.json'), read('evidence.json')
    resource_validation = read('resource-validation.json')
    if (set(evidence['stress']) != {'txt_long', 'epub_long'}
            and resource_validation.get('status') != 'incomplete-stopped-at-user-request'):
        raise ValueError('Both completed endurance scenes are required before packaging')
    if analysis['errors'] or analysis['positionMismatches']:
        raise ValueError('Unresolved measurement validation failures')
    reports = [r for r in analysis['runs'] if r['config']['id'].startswith('foreground-')
        and ('-matrix-' in r['config']['id'] or '-measured-full-' in r['config']['id'])]
    source_files = [OUT / name for name in ['frozen.json', 'candidate.patch', 'manifest-A.json', 'manifest-B.json',
        'manifest-input-v1-A.json', 'manifest-input-v1-B.json', 'manifest-input-A.json', 'manifest-input-B.json',
        'environment.json', 'samples.json', 'analysis.json', 'summary.json', 'evidence.json', 'checks.json',
        'resource-validation.json',
        'root-analyze.log', 'design-tokens.log', 'core-tests.log', 'sample-tests.log']]
    source_files += sorted((OUT / 'results').rglob('*'))
    files = [p for p in source_files if p.is_file()]
    index = {str(p.relative_to(OUT)).replace('\\', '/'): {'bytes': p.stat().st_size, 'sha256': digest(p)} for p in files}
    (OUT / 'evidence-index.json').write_text(json.dumps(index, indent=2), encoding='utf-8')
    archive = OUT / 'reader_13a_evidence.zip'
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in files + [OUT / 'evidence-index.json']:
            bundle.write(path, str(path.relative_to(OUT)))
        for path in sorted((ROOT / 'tool/reader_baseline').glob('*13a*')):
            if path.is_file() and path.name != 'README_13A.md': bundle.write(path, 'tools/' + path.name)
        bundle.write(ROOT / 'tool/reader_baseline/README_13A.md', 'tools/README_13A.md')
    baseline = {'schema': 1, 'dates': ['2026-10-31', '2026-11-01', '2026-11-04'],
        'status': 'diagnostic-reported-performance-not-accepted',
        'provenance': read('frozen.json'), 'environment': read('environment.json'), 'samples': read('samples.json'),
        'foregroundPairedTurns': sum(r['turns'] for r in reports if r['config']['variant'] == 'A'),
        'positionMismatches': analysis['positionMismatches'], 'analysisErrors': analysis['errors'],
        'summary': read('summary.json'), 'rounds': reports,
        'phases': evidence['phases'], 'stageDurationMs': evidence['stageDurationMs'],
        'stress': evidence['stress'],
        'partialStress': evidence['partialStress'], 'resourceValidation': resource_validation,
        'inputAudits': [{k:v for k,v in a.items() if k not in ['imageLayoutEvents','positionChecks']}
            for a in evidence['inputAudits']],
        'heavySystemCorrelation': {v:read(f'results/foreground-apptrace-heavy-{v}/system-correlation.json') for v in ['A','B']},
        'checks': {'exitCodes': read('checks.json'), 'corePassed':184, 'coreSkippedWindows':4,
            'samplePassed':12, 'diagnosticUnitPassed':10,
            'existingStaticInfos':2, 'existingDesignTokenViolations':True},
        'archive': {'relativePath': str(archive.relative_to(ROOT)).replace('\\','/'),
            'bytes':archive.stat().st_size, 'sha256':digest(archive),
            'entries': len(bundle.namelist())},
        'limits':['Android emulator only', 'No hardware input-to-photon measurement',
            'First scene pair is not fully cold disk/driver/image caching', 'No GPU hardware counters',
            'Synthetic text PDF only', 'Continuous 20-minute resource validation incomplete at user request',
            'RSS samples do not measure every peak or prove absence of GPU leaks']}
    target = ROOT / 'docs/baselines/reader_performance_13a_2026-11-04.json'
    target.write_text(json.dumps(baseline, indent=2), encoding='utf-8')
    print(json.dumps({'baseline':str(target), 'archiveBytes':archive.stat().st_size,
        'archiveSha256':baseline['archive']['sha256'], 'pairedTurns':baseline['foregroundPairedTurns']}, indent=2))


if __name__ == '__main__': main()
