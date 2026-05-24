import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/ble_constants.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/devices_notifier.dart';

// ── Steps ────────────────────────────────────────────────────────────────────

enum _Step { scan, configure, provisioning, done }

// ── Sheet ────────────────────────────────────────────────────────────────────

class AddDeviceSheet extends ConsumerStatefulWidget {
  const AddDeviceSheet({super.key});

  @override
  ConsumerState<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<AddDeviceSheet> {
  _Step _step = _Step.scan;

  // Scan state
  final List<ScanResult> _found = [];
  bool _scanning = false;
  String? _scanError;

  // Selected device
  ScanResult? _selected;

  // Configure form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  // Provisioning state
  String _provisionStatus = '';
  String? _provisionError;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _nameCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Scan ─────────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _scanError = null;
      _found.clear();
    });

    try {
      await FlutterBluePlus.startScan(
        withNames: [BleConstants.deviceNamePrefix],
        timeout: const Duration(seconds: 10),
      );

      FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          _found
            ..clear()
            ..addAll(
              results.where((r) =>
                  r.device.platformName
                      .startsWith(BleConstants.deviceNamePrefix)),
            );
        });
      });

      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      if (mounted) setState(() => _scanError = e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _selectDevice(ScanResult result) {
    FlutterBluePlus.stopScan();
    setState(() {
      _selected = result;
      _step = _Step.configure;
    });
  }

  // ── Provision ────────────────────────────────────────────────────────────

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _step = _Step.provisioning;
      _provisionStatus = 'Connexion BLE…';
      _provisionError = null;
    });

    BluetoothDevice device = _selected!.device;

    try {
      // 1. Connect BLE
      await device.connect(timeout: const Duration(seconds: 10));
      _setStatus('Connexion BLE réussie…');

      // 2. Create device in backend → get UUID
      _setStatus('Création de l\'appareil…');
      final macAddress = device.remoteId.str; // BLE MAC = device MAC on Android
      final created = await ref.read(devicesNotifierProvider.notifier).create(
            name: _nameCtrl.text.trim(),
            macAddress: macAddress,
          );
      if (created == null) throw Exception('Échec création appareil');

      // 3. Discover BLE services
      _setStatus('Envoi des informations WiFi…');
      final services = await device.discoverServices();
      final svc = services.firstWhere(
        (s) => s.serviceUuid.str.toLowerCase() == BleConstants.serviceUuid,
        orElse: () => throw Exception('Service NUS introuvable sur l\'ESP32'),
      );
      final rxChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str.toLowerCase() == BleConstants.rxCharUuid,
        orElse: () => throw Exception('Caractéristique RX introuvable'),
      );

      // 4. Write provisioning JSON
      final payload = jsonEncode({
        'ssid': _ssidCtrl.text.trim(),
        'password': _passCtrl.text,
        'mqttBroker': ApiConstants.mqttBroker,
        'deviceId': created.id,
      });
      await rxChar.write(utf8.encode(payload), withoutResponse: false);

      // 5. Disconnect — ESP32 will reboot
      _setStatus('Configuration envoyée, redémarrage ESP32…');
      await device.disconnect();

      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      try {
        await device.disconnect();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _step = _Step.configure;
          _provisionError = e is Exception
              ? e.toString().replaceAll('Exception: ', '')
              : extractDioError(e);
        });
      }
    }
  }

  void _setStatus(String msg) {
    if (mounted) setState(() => _provisionStatus = msg);
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: switch (_step) {
        _Step.scan        => _buildScan(),
        _Step.configure   => _buildConfigure(),
        _Step.provisioning => _buildProvisioning(),
        _Step.done        => _buildDone(),
      },
    );
  }

  // ── Step 1 : Scan ──────────────────────────────────────────────────────

  Widget _buildScan() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          title: 'Recherche ESP32',
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 16),

        if (_scanError != null)
          ErrorBanner(
            message: _scanError!,
            onDismiss: () => setState(() => _scanError = null),
          ),

        if (_scanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Scan BLE en cours…'),
              ],
            ),
          ),

        if (_found.isEmpty && !_scanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.bluetooth_searching, size: 48),
                  SizedBox(height: 8),
                  Text('Aucun ESP32 trouvé'),
                  SizedBox(height: 4),
                  Text(
                    'Assurez-vous que l\'ESP32 est alimenté\net en mode provisioning.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        ..._found.map(
          (r) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.developer_board)),
            title: Text(r.device.platformName),
            subtitle: Text(r.device.remoteId.str),
            trailing: Text(
              '${r.rssi} dBm',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _selectDevice(r),
          ),
        ),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _scanning ? null : _startScan,
          icon: const Icon(Icons.refresh),
          label: const Text('Relancer le scan'),
        ),
      ],
    );
  }

  // ── Step 2 : Configure ─────────────────────────────────────────────────

  Widget _buildConfigure() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: _selected!.device.platformName,
            subtitle: _selected!.device.remoteId.str,
            onClose: () => setState(() => _step = _Step.scan),
            closeIcon: Icons.arrow_back,
          ),
          const SizedBox(height: 16),

          if (_provisionError != null) ...[
            ErrorBanner(
              message: _provisionError!,
              onDismiss: () => setState(() => _provisionError = null),
            ),
            const SizedBox(height: 12),
          ],

          AppTextField(
            controller: _nameCtrl,
            label: "Nom de l'appareil",
            hint: 'Ex: ESP32 Salon',
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ requis' : null,
          ),
          const SizedBox(height: 12),

          AppTextField(
            controller: _ssidCtrl,
            label: 'Réseau WiFi (SSID)',
            hint: 'MonWiFi',
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ requis' : null,
          ),
          const SizedBox(height: 12),

          AppTextField(
            controller: _passCtrl,
            label: 'Mot de passe WiFi',
            obscureText: !_showPass,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Champ requis' : null,
            onSubmitted: (_) => _provision(),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Configurer',
            onPressed: _provision,
          ),
        ],
      ),
    );
  }

  // ── Step 3 : Provisioning ──────────────────────────────────────────────

  Widget _buildProvisioning() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          _provisionStatus,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Step 4 : Done ──────────────────────────────────────────────────────

  Widget _buildDone() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.check_circle_outline,
            size: 72, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          '${_nameCtrl.text} configuré !',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'L\'ESP32 redémarre et se connecte au WiFi.\nIl apparaîtra en ligne dans quelques secondes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Terminer'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Shared header widget ─────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final IconData closeIcon;

  const _SheetHeader({
    required this.title,
    this.subtitle,
    required this.onClose,
    this.closeIcon = Icons.close,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
        ),
        IconButton(icon: Icon(closeIcon), onPressed: onClose),
      ],
    );
  }
}
