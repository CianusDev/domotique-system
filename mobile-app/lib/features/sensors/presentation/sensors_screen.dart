import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../actuators/data/actuator_model.dart';
import '../../actuators/domain/actuators_notifier.dart';
import '../data/sensor_model.dart';
import '../domain/sensor_readings_notifier.dart';
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
          // ── Actionneurs ─────────────────────────────────────────
          _SectionHeader(
            title: 'Actionneurs',
            onAdd: () => _showAddActuatorDialog(),
          ),
          const SizedBox(height: 8),
          if (actuators.isEmpty)
            _EmptySection(label: 'Aucun actionneur — appuyez sur + pour ajouter')
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
                    deviceId: widget.deviceId,
                    onDelete: () => _confirmDelete(s),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _showAddActuatorDialog() async {
    final result = await showDialog<_ActuatorFormResult>(
      context: context,
      builder: (_) => const _AddActuatorDialog(),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(actuatorsNotifierProvider(widget.deviceId).notifier)
          .create(type: result.type, name: result.name, pin: result.pin);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur création actionneur')),
        );
      }
    }
  }

  Future<void> _confirmDeleteActuator(ActuatorModel actuator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'actionneur'),
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
            const SnackBar(content: Text('Erreur suppression actionneur')),
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

class _SensorCard extends ConsumerWidget {
  final SensorModel sensor;
  final String deviceId;
  final VoidCallback onDelete;

  const _SensorCard({
    required this.sensor,
    required this.deviceId,
    required this.onDelete,
  });

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
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(context);
    final readings = ref.watch(sensorReadingsProvider(deviceId));
    final latest = readings[sensor.id];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
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
              if (latest != null) ...[
                const SizedBox(height: 4),
                _SensorReadingRow(payload: latest),
              ] else if (sensor.lastReadAt != null) ...[
                Text(
                  'Dernière lecture: ${_formatTime(sensor.lastReadAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

// ── Live reading display ──────────────────────────────────────────────────────

class _SensorReadingRow extends StatelessWidget {
  final Map<String, dynamic> payload;
  const _SensorReadingRow({required this.payload});

  @override
  Widget build(BuildContext context) {
    final chips = _buildChips(context);
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  List<Widget> _buildChips(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final chips = <Widget>[];

    // ── Temperature ────────────────────────────────────────────────
    if (payload.containsKey('temperature')) {
      final v = (payload['temperature'] as num).toDouble();
      chips.add(_Chip(
        icon: Icons.thermostat,
        label: '${v.toStringAsFixed(1)} °C',
        color: _tempColor(v),
        style: style,
      ));
    }

    // ── Humidity ───────────────────────────────────────────────────
    if (payload.containsKey('humidity')) {
      final v = (payload['humidity'] as num).toDouble();
      chips.add(_Chip(
        icon: Icons.water_drop,
        label: '${v.toStringAsFixed(0)} %',
        color: Colors.blue,
        style: style,
      ));
    }

    // ── Light / LDR ────────────────────────────────────────────────
    if (payload.containsKey('light')) {
      final lux = (payload['light'] as num).toDouble();
      final level = payload['level'] as String? ?? '';
      chips.add(_Chip(
        icon: Icons.wb_sunny,
        label: '${lux.toStringAsFixed(0)} lux${level.isNotEmpty ? ' · $level' : ''}',
        color: Colors.amber.shade700,
        style: style,
      ));
    }

    // ── Motion / PIR ───────────────────────────────────────────────
    if (payload.containsKey('motion')) {
      final motion = payload['motion'] as bool? ?? false;
      chips.add(_Chip(
        icon: motion ? Icons.directions_run : Icons.bedroom_parent,
        label: motion ? 'Mouvement' : 'Calme',
        color: motion ? Colors.orange : Colors.grey,
        style: style,
      ));
    }

    // ── Distance / HC-SR04 ─────────────────────────────────────────
    if (payload.containsKey('distance')) {
      final v = (payload['distance'] as num).toDouble();
      chips.add(_Chip(
        icon: Icons.straighten,
        label: '${v.toStringAsFixed(1)} cm',
        color: Colors.teal,
        style: style,
      ));
    }

    // ── Pressure / BME280 ──────────────────────────────────────────
    if (payload.containsKey('pressure')) {
      final v = (payload['pressure'] as num).toDouble();
      chips.add(_Chip(
        icon: Icons.compress,
        label: '${v.toStringAsFixed(0)} hPa',
        color: Colors.purple,
        style: style,
      ));
    }

    return chips;
  }

  Color _tempColor(double t) {
    if (t < 10) return Colors.blue;
    if (t < 20) return Colors.lightBlue;
    if (t < 28) return Colors.green;
    if (t < 35) return Colors.orange;
    return Colors.red;
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final TextStyle? style;
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: style?.copyWith(color: color) ??
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
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

// ── Add actuator dialog ──────────────────────────────────────────────────────
// Proper StatefulWidget so the controllers are disposed at the right time by
// Flutter — disposing them manually after `await showDialog(...)` triggered
// 'failed assertion: _dependents.isEmpty' because the text fields were still
// in the disposing widget tree.

class _ActuatorFormResult {
  final String type;
  final String name;
  final int    pin;
  const _ActuatorFormResult(this.type, this.name, this.pin);
}

class _AddActuatorDialog extends StatefulWidget {
  const _AddActuatorDialog();

  @override
  State<_AddActuatorDialog> createState() => _AddActuatorDialogState();
}

class _AddActuatorDialogState extends State<_AddActuatorDialog> {
  static const _types = [
    ('led',    'LED'),
    ('relay',  'Relais'),
    ('servo',  'Servo'),
    ('buzzer', 'Buzzer'),
  ];

  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  String _type = 'led';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ActuatorFormResult(
        _type,
        _nameCtrl.text.trim(),
        int.parse(_pinCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un actionneur'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Ex: LED salon',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _types
                    .map((t) => DropdownMenuItem(
                          value: t.$1,
                          child: Text(t.$2),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'led'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Broche GPIO',
                  hintText: 'Ex: 2',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0 || n > 39) {
                    return 'GPIO invalide (0–39)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
