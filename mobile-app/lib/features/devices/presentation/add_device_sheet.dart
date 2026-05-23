import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/devices_notifier.dart';

class AddDeviceSheet extends ConsumerStatefulWidget {
  const AddDeviceSheet({super.key});

  @override
  ConsumerState<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<AddDeviceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _macCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _macCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(devicesNotifierProvider.notifier).create(
            name: _nameCtrl.text.trim(),
            macAddress: _macCtrl.text.trim().toUpperCase(),
            ipAddress: _ipCtrl.text.trim(),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Ajouter un appareil',
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

            AppTextField(
              controller: _nameCtrl,
              label: "Nom de l'appareil",
              hint: 'Ex: ESP32 Salon',
              textInputAction: TextInputAction.next,
              enabled: !_loading,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),

            AppTextField(
              controller: _macCtrl,
              label: 'Adresse MAC',
              hint: 'AA:BB:CC:DD:EE:FF',
              textInputAction: TextInputAction.next,
              enabled: !_loading,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ requis';
                final mac = v.trim().toUpperCase();
                final valid = RegExp(
                  r'^([0-9A-F]{2}[:\-]){5}[0-9A-F]{2}$',
                ).hasMatch(mac);
                if (!valid) return 'Format: AA:BB:CC:DD:EE:FF';
                return null;
              },
            ),
            const SizedBox(height: 12),

            AppTextField(
              controller: _ipCtrl,
              label: 'Adresse IP (optionnel)',
              hint: '192.168.1.x',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !_loading,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Ajouter',
              onPressed: _loading ? null : _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
