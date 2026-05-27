import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/sensor_type_model.dart';
import '../data/sensor_repository.dart';
import '../domain/sensors_notifier.dart';

class AddSensorSheet extends ConsumerStatefulWidget {
  final String deviceId;
  const AddSensorSheet({super.key, required this.deviceId});

  @override
  ConsumerState<AddSensorSheet> createState() => _AddSensorSheetState();
}

class _AddSensorSheetState extends ConsumerState<AddSensorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  SensorTypeModel? _selectedType;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      setState(() => _error = 'Sélectionnez un type de capteur');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sensorsNotifierProvider(widget.deviceId).notifier).addSensor(
            sensorTypeId: _selectedType!.id,
            name: _nameCtrl.text.trim(),
            pin: int.parse(_pinCtrl.text.trim()),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = extractDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(sensorTypesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Ajouter un capteur',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              ErrorBanner(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
            ],

            // Sensor type dropdown
            typesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorBanner(message: e.toString()),
              data: (types) => DropdownButtonFormField<SensorTypeModel>(
                initialValue: _selectedType,
                hint: const Text('Type de capteur'),
                isExpanded: true,
                // Each menu row needs ~48 px for two lines of text
                itemHeight: 48,
                // When closed, show only "TYPE — short name" on one line
                selectedItemBuilder: (ctx) => types
                    .map((t) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${t.type} — ${t.name}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ))
                    .toList(),
                items: types
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.type,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              t.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (v) => setState(() => _selectedType = v),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  labelText: 'Type de capteur',
                ),
                validator: (_) =>
                    _selectedType == null ? 'Sélectionnez un type' : null,
              ),
            ),
            const SizedBox(height: 12),

            AppTextField(
              controller: _nameCtrl,
              label: 'Nom du capteur',
              hint: 'Ex: Température salon',
              textInputAction: TextInputAction.next,
              enabled: !_loading,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),

            AppTextField(
              controller: _pinCtrl,
              label: 'GPIO Pin',
              hint: 'Ex: 4',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_loading,
              suffixIcon: const Tooltip(
                message: 'Numéro de la broche GPIO ESP32',
                child: Icon(Icons.help_outline, size: 18),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Champ requis';
                final n = int.tryParse(v);
                if (n == null || n < 0 || n > 39) {
                  return 'Pin GPIO valide: 0–39';
                }
                return null;
              },
              onSubmitted: (_) => _submit(),
            ),

            // Show data fields info for selected type
            if (_selectedType != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Données publiées:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    ..._selectedType!.dataFields.map(
                      (f) => Text(
                        '• ${f.field} (${f.unit})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Ajouter',
              onPressed: _loading ? null : _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
