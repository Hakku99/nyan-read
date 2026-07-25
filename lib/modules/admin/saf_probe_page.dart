import 'package:flutter/material.dart';

import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/components/nyan_primary_button.dart';
import '../../core/utils/book_source_access.dart';
import '../../core/utils/book_source_platform.dart';

/// Dev-only SAF probe for the library-folders Phase A gate
/// (docs/DESIGN_LIBRARY_FOLDERS.md §9). Drives the native tree-grant
/// methods against a real device/emulator and prints raw outcomes.
///
/// Deliberately NOT localized: this page ships behind the admin panel for
/// the verification session only and is removed (or flag-gated) before any
/// release build. TODO(#library-folders): remove after Phase A gate passes.
class SafProbePage extends StatefulWidget {
  const SafProbePage({super.key});

  @override
  State<SafProbePage> createState() => _SafProbePageState();
}

class _SafProbePageState extends State<SafProbePage> {
  final List<String> _log = <String>[];
  String? _lastTreeUri;
  String? _firstDocUri;

  void _append(String line) {
    // Mirrored to logcat so the desktop side of a verification session can
    // read outcomes without transcribing from the screen.
    debugPrint('[SAF-probe] $line');
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    _append('▶ $label');
    try {
      await action();
    } catch (e) {
      _append('✗ $label failed: $e');
    }
  }

  Future<void> _refreshGrants() => _run('list grants', () async {
        final result = await BookSourcePlatform.listPersistedPermissions();
        final trees = (result['trees'] as List?) ?? const [];
        _append('grants total=${result['totalCount']} trees=${trees.length}');
        for (final tree in trees) {
          _append('  tree: ${tree['name']} → ${tree['uri']}');
        }
      });

  Future<void> _pickFolder() => _run('pick folder', () async {
        final result = await BookSourcePlatform.pickLibraryFolder();
        if (result == null) {
          _append('cancelled');
          return;
        }
        _lastTreeUri = result['uri'] as String?;
        _append('picked "${result['name']}"');
        _append('  $_lastTreeUri');
      });

  Future<void> _scanFolder() => _run('scan folder', () async {
        final treeUri = _lastTreeUri;
        if (treeUri == null) {
          _append('pick a folder first');
          return;
        }
        final result = await BookSourcePlatform.listTreeDocuments(treeUri);
        final docs = (result['documents'] as List?) ?? const [];
        _append('found ${docs.length} book files in ${result['elapsedMs']}ms'
            ' truncated=${result['truncated']}');
        for (final doc in docs.take(12)) {
          _append('  ${doc['name']} (${doc['size']}B)');
        }
        if (docs.isNotEmpty) {
          _firstDocUri = docs.first['uri'] as String?;
        }
      });

  Future<void> _readFirstFile() => _run('read first file', () async {
        final uri = _firstDocUri;
        if (uri == null) {
          _append('scan a folder first');
          return;
        }
        // The exact production path: child doc uri → native temp copy →
        // bytes. Proves tree-derived uris flow through openInputStream.
        final bytes = await BookSourceAccess.readBytesFor(
          sourceType: 'android_content_uri',
          sourceLocator: uri,
        );
        final preview = String.fromCharCodes(bytes.take(60));
        _append('read ${bytes.length}B: "$preview"');
      });

  Future<void> _releaseFolder() => _run('release folder', () async {
        final treeUri = _lastTreeUri;
        if (treeUri == null) {
          _append('pick a folder first');
          return;
        }
        final released =
            await BookSourcePlatform.releasePersistedPermission(treeUri);
        _append('released=$released');
      });

  Future<void> _quotaStress() => _run('quota stress (multi-pick)', () async {
        final result = await BookSourcePlatform.pickAndPersistManyFiles();
        if (result == null) {
          _append('cancelled');
          return;
        }
        _append('attempted=${result['attempted']}'
            ' persisted=${result['persisted']} failed=${result['failed']}');
        _append('grant count after=${result['grantCountAfter']}');
        final firstError = result['firstError'];
        if (firstError != null) _append('first error: $firstError');
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);

    final actions = <(String, Future<void> Function())>[
      // Post-restart continuation: probe uris are in-memory, so reload the
      // known emulator fixtures to test evicted-grant behavior cold.
      ('Load fixtures', () async {
        _lastTreeUri =
            'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fquota_probe';
        _firstDocUri =
            'content://com.android.externalstorage.documents/tree/primary%3ADownload%2Fquota_probe/document/primary%3ADownload%2Fquota_probe%2Fp1.txt';
        _append('fixtures loaded (quota_probe tree + p1.txt)');
      }),
      ('List grants', _refreshGrants),
      ('Pick library folder', _pickFolder),
      ('Scan folder', _scanFolder),
      ('Read first file', _readFirstFile),
      ('Release folder', _releaseFolder),
      ('Quota stress (multi-pick)', _quotaStress),
      ('Release ALL grants', () => _run('release ALL', () async {
            final released =
                await BookSourcePlatform.releaseAllPersistedPermissions();
            _append('released $released grants');
          })),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SAF Probe',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NyanSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: NyanSpacing.space8,
                runSpacing: NyanSpacing.space8,
                children: [
                  for (final (label, action) in actions)
                    NyanPrimaryButton(
                      label: label,
                      size: NyanPrimaryButtonSize.compact,
                      onPressed: () => action(),
                    ),
                ],
              ),
              const SizedBox(height: NyanSpacing.space12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(NyanSpacing.space12),
                  decoration: BoxDecoration(
                    color: nyan.surfaceMuted,
                    borderRadius:
                        BorderRadius.circular(NyanRadius.cardNested),
                  ),
                  child: ListView.builder(
                    reverse: false,
                    itemCount: _log.length,
                    itemBuilder: (context, index) => Text(
                      _log[index],
                      style: TextStyle(
                        fontFamily: NyanTypography.monoFontFamily,
                        fontSize: NyanTypography.meta,
                        height: 1.4,
                        color: nyan.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
