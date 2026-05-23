import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sensor_model.dart';
import '../domain/sensors_notifier.dart';
import 'add_sensor_sheet.dart';

class SensorsScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final String deviceName;

  const SensorsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  ConsumerState<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends ConsumerState<SensorsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(sensorsNotifierProvider(widget.deviceId).notifier)
          .load(),
    );
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddSensorSheet(deviceId: widget.deviceId),
    );
  }

  Future<void> _confirmDelete(SensorModel sensor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le capteur'),
        content: Text('Supprimer "${sensor.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref
            .read(sensorsNotifierProvider(widget.deviceId).notifier)
            .delete(sensor.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensorsAsync =
        ref.watch(sensorsNotifierProvider(widget.deviceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(sensorsNotifierProvider(widget.deviceId).notifier)
                .load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.sensors),
        label: const Text('Ajouter'),
      ),
      body: sensorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(e.toString()),
        data: (sensors) =>
            sensors.isEmpty ? _buildEmpty() : _buildList(sensors),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => ref
                .read(sensorsNotifierProvider(widget.deviceId).notifier)
                .load(),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors_off,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Aucun capteur',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier capteur',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<SensorModel> sensors) {
    return RefreshIndicator(
      onRefresh: () => ref
          .read(sensorsNotifierProvider(widget.deviceId).notifier)
          .load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sensors.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _SensorCard(
          sensor: sensors[i],
          onDelete: () => _confirmDelete(sensors[i]),
        ),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final SensorModel sensor;
  final VoidCallback onDelete;

  const _SensorCard({required this.sensor, required this.onDelete});

  Color _statusColor(BuildContext context) {
    return switch (sensor.status) {
      SensorStatus.active => Colors.green,
      SensorStatus.error => Theme.of(context).colorScheme.error,
      SensorStatus.inactive => Colors.grey,
    };
  }

  String _statusLabel() {
    return switch (sensor.status) {
      SensorStatus.active => 'Actif',
      SensorStatus.error => 'Erreur',
      SensorStatus.inactive => 'En attente',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.sensors,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(sensor.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPIO ${sensor.pin}'),
            if (sensor.lastReadAt != null)
              Text(
                'Dernière lecture: ${_formatTime(sensor.lastReadAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel(),
                    style: TextStyle(color: color, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Theme.of(context).colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
    return 'Il y a ${diff.inDays} j';
  }
}
