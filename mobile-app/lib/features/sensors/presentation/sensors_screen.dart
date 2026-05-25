import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../actuators/data/actuator_model.dart';
import '../../actuators/domain/actuators_notifier.dart';
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
    Future.microtask(() {
      ref.read(sensorsNotifierProvider(widget.deviceId).notifier).load();
      ref.read(actuatorsNotifierProvider(widget.deviceId).notifier).load();
    });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(sensorsNotifierProvider(widget.deviceId).notifier).load();
              ref.read(actuatorsNotifierProvider(widget.deviceId).notifier).load();
            },
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final sensorsAsync = ref.watch(sensorsNotifierProvider(widget.deviceId));
    final actuatorsAsync = ref.watch(actuatorsNotifierProvider(widget.deviceId));

    if (sensorsAsync.isLoading && actuatorsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final sensors = sensorsAsync.valueOrNull ?? [];
    final actuators = actuatorsAsync.valueOrNull ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(sensorsNotifierProvider(widget.deviceId).notifier).load();
        await ref.read(actuatorsNotifierProvider(widget.deviceId).notifier).load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Actuateurs ──────────────────────────────────────────
          _SectionHeader(
            title: 'Actuateurs',
            onAdd: () => _showAddActuatorDialog(),
          ),
          const SizedBox(height: 8),
          if (actuators.isEmpty)
            _EmptySection(label: 'Aucun actuateur — appuyez sur + pour ajouter')
          else
            ...actuators.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ActuatorCard(
                    actuator: a,
                    onToggle: () => ref
                        .read(actuatorsNotifierProvider(widget.deviceId).notifier)
                        .control(a.id, command: 'toggle'),
                    onDelete: () => _confirmDeleteActuator(a),
                  ),
                )),

          const SizedBox(height: 24),

          // ── Capteurs ────────────────────────────────────────────
          _SectionHeader(title: 'Capteurs', onAdd: _openAddSheet),
          const SizedBox(height: 8),
          if (sensors.isEmpty)
            _EmptySection(label: 'Aucun capteur — appuyez sur + pour ajouter')
          else
            ...sensors.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SensorCard(
                    sensor: s,
                    onDelete: () => _confirmDelete(s),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _showAddActuatorDialog() async {
    final nameCtrl = TextEditingController(text: 'LED Bleue');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter LED'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 8),
            const Text('Type: LED  •  GPIO: 2 (built-in)',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(actuatorsNotifierProvider(widget.deviceId).notifier)
                    .create(type: 'led', name: nameCtrl.text.trim(), pin: 2);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erreur création actuateur')),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteActuator(ActuatorModel actuator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer "${actuator.name}" ?'),
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
            .read(actuatorsNotifierProvider(widget.deviceId).notifier)
            .delete(actuator.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur suppression')),
          );
        }
      }
    }
  }

  // ignore: unused_element
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
            onPressed: () {
              ref.read(sensorsNotifierProvider(widget.deviceId).notifier).load();
              ref.read(actuatorsNotifierProvider(widget.deviceId).notifier).load();
            },
            child: const Text('Réessayer'),
          ),
        ],
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

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            )),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: onAdd,
          tooltip: 'Ajouter',
        ),
      ],
    );
  }
}

// ── Empty section placeholder ─────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final String label;
  const _EmptySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

// ── Actuator card ─────────────────────────────────────────────────────────────

class _ActuatorCard extends StatelessWidget {
  final ActuatorModel actuator;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ActuatorCard({
    required this.actuator,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOn = actuator.isOn;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOn
              ? cs.primaryContainer
              : cs.surfaceContainerHighest,
          child: Icon(
            Icons.lightbulb,
            color: isOn ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
        title: Text(actuator.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('GPIO ${actuator.pin}  •  ${actuator.type.toUpperCase()}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: isOn,
              onChanged: (_) => onToggle(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: cs.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
