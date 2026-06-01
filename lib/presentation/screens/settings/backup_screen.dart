// lib/presentation/screens/settings/backup_screen.dart
// Pantalla de backup — exporta todos los datos del negocio a JSON.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/backup_repository.dart';
import '../../../providers/business_provider.dart';
import '../../../services/powersync_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    final repo = BackupRepository(PowerSyncService.db);
    final stats = await repo.getBackupStats(business.id);
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _exportBackup() async {
    final business = ref.read(currentBusinessProvider).valueOrNull;
    if (business == null) return;

    // Confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exportar backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Se generará un archivo JSON con todos tus datos. '
                'Guárdalo en un lugar seguro.\n'),
            if (_stats != null) ...[
              const Text('Datos a incluir:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._stats!.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text('${e.value}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exportar')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = BackupRepository(PowerSyncService.db);
      final backup = await repo.generateBackup(business.id);

      // Serializar a JSON con indentación
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

      // Guardar en directorio temporal
      final dir = await getTemporaryDirectory();
      final filename =
          'poscuba_backup_${DateFormatter.formatForFilename(DateTime.now())}.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr, encoding: utf8);

      // Compartir
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup POS Cuba — ${business.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al generar backup: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final businessAsync = ref.watch(currentBusinessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup y restauración')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Sección exportar ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined, color: cs.primary, size: 28),
                      const SizedBox(width: 12),
                      Text('Exportar backup',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Genera un archivo JSON con todos tus productos, ventas, '
                    'trabajadores y movimientos. Guárdalo en Drive, WhatsApp '
                    'o donde prefieras.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),

                  // Stats
                  if (_stats != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _stats!.entries
                            .map((e) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key,
                                          style: theme.textTheme.bodySmall),
                                      Text('${e.value}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _exportBackup,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download_outlined),
                      label: Text(
                          _isLoading ? 'Generando...' : 'Exportar backup'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Nota informativa ─────────────────────────────────────────────
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La restauración desde un backup se hace manualmente '
                      'con ayuda del desarrollador. El archivo JSON contiene '
                      'todos tus datos en formato estándar.',
                      style: TextStyle(
                          color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Nombre del negocio ────────────────────────────────────────────
          businessAsync.when(
            data: (b) => b == null
                ? const SizedBox.shrink()
                : ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(b.name),
                    subtitle: const Text('Negocio activo'),
                    tileColor: cs.surfaceVariant.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
