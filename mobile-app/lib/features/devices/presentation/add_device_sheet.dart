import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/ble_constants.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/devices_notifier.dart';

// ── WiFi network model ────────────────────────────────────────────────────────

class _WifiNet {
  final String ssid;
  final int rssi;
  final bool isOpen;

  const _WifiNet({required this.ssid, required this.rssi, required this.isOpen});

  /// 1–4 signal bars based on RSSI
  int get bars {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    return 1;
  }
}

// ── Steps ────────────────────────────────────────────────────────────────────

enum _Step { bleScan, configure, wifiPick, provisioning, done }

// ── Sheet ────────────────────────────────────────────────────────────────────

class AddDeviceSheet extends ConsumerStatefulWidget {
  const AddDeviceSheet({super.key});

  @override
  ConsumerState<AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<AddDeviceSheet> {
  _Step _step = _Step.bleScan;

  // ── BLE device scan (step 1) ───────────────────────────────────────────
  final List<ScanResult> _found = [];
  bool _scanning = false;
  String? _scanError;
  ScanResult? _selected;

  // ── BLE connection (shared steps 2–4) ─────────────────────────────────
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;
  bool _bleConnecting = false;

  // ── Configure (step 2) ────────────────────────────────────────────────
  final _nameFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  // ── WiFi pick (step 3) ────────────────────────────────────────────────
  List<_WifiNet> _wifiNetworks = [];
  bool _wifiScanning = false;
  String? _wifiError;
  _WifiNet? _selectedWifi;
  bool _manualEntry = false;
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  String? _wifiFormError;
  String? _lastFailedSsid; // set when ESP32 reports captive_portal on last boot

  // ── Provisioning (step 4) ─────────────────────────────────────────────
  String _provisionStatus = '';
  String? _provisionError;

  @override
  void initState() {
    super.initState();
    _startBleScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _bleDevice?.disconnect().catchError((_) {});
    _nameCtrl.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── BLE device scan ────────────────────────────────────────────────────

  Future<void> _startBleScan() async {
    setState(() {
      _scanning = true;
      _scanError = null;
      _found.clear();
    });

    try {
      final btStatuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final btDenied = btStatuses.entries
          .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
          .toList();

      if (btDenied.isNotEmpty) {
        final permanent = btDenied.any((e) => e.value.isPermanentlyDenied);
        if (permanent && mounted) {
          setState(() => _scanning = false);
          _showPermissionDialog();
          return;
        }
        throw Exception('Permissions Bluetooth refusées');
      }

      await Permission.locationWhenInUse.request();

      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );

      FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          _found
            ..clear()
            ..addAll(results.where((r) =>
                r.device.platformName.startsWith(BleConstants.deviceNamePrefix) ||
                r.advertisementData.serviceUuids
                    .any((u) => u.str128.toLowerCase() == BleConstants.serviceUuid)));
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

  // ── BLE connection management ──────────────────────────────────────────

  /// Connect BLE and discover NUS characteristics. Reuses existing connection.
  ///
  /// Verifies actual connection state — WiFi scan on ESP32 can drop BLE
  /// (shared 2.4GHz radio). Reconnects transparently if stale.
  /// Requests MTU 512 so large payloads (provision JSON, wifi_list) fit.
  Future<void> _ensureBleConnected() async {
    // Check actual connection state, not just cached refs
    if (_bleDevice != null && _rxChar != null && _txChar != null) {
      if (_bleDevice!.isConnected) return;
      // Connection dropped (e.g. during WiFi scan) — clear stale cache
      _bleDevice = null;
      _rxChar    = null;
      _txChar    = null;
    }

    if (mounted) setState(() => _bleConnecting = true);
    try {
      final device = _selected!.device;
      await device.connect(timeout: const Duration(seconds: 10));
      _bleDevice = device;

      // Request larger MTU — default 23-byte frame = only 20-byte payload,
      // not enough for provision JSON or wifi_list response chunks.
      await device.requestMtu(512).catchError((_) => 0);

      // Short settle: BLE stack needs a moment after MTU negotiation
      await Future.delayed(const Duration(milliseconds: 300));

      final services = await device.discoverServices();
      final svc = services.firstWhere(
        (s) => s.serviceUuid.str.toLowerCase() == BleConstants.serviceUuid,
        orElse: () => throw Exception('Service NUS introuvable sur l\'ESP32'),
      );

      _rxChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str.toLowerCase() == BleConstants.rxCharUuid,
        orElse: () => throw Exception('Caractéristique RX introuvable'),
      );
      _txChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str.toLowerCase() == BleConstants.txCharUuid,
        orElse: () => throw Exception('Caractéristique TX introuvable'),
      );
    } finally {
      if (mounted) setState(() => _bleConnecting = false);
    }
  }

  Future<void> _disconnectBle() async {
    try { await _bleDevice?.disconnect(); } catch (_) {}
    _bleDevice = null;
    _rxChar = null;
    _txChar = null;
  }

  // ── WiFi scan via BLE NUS ──────────────────────────────────────────────

  /// Send scan_wifi command to ESP32, collect TX response.
  ///
  /// ESP32 must respond with:
  /// {"type":"wifi_list","networks":[{"ssid":"…","rssi":-65,"auth":3},…]}
  /// auth=0 → OPEN, auth≥1 → secured
  Future<void> _requestWifiScan() async {
    setState(() {
      _wifiScanning = true;
      _wifiError = null;
      _wifiNetworks = [];
    });

    try {
      await _ensureBleConnected();

      await _txChar!.setNotifyValue(true);

      final completer = Completer<List<_WifiNet>>();
      final buffer = StringBuffer();

      final sub = _txChar!.onValueReceived.listen((data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
        try {
          final json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
          if (json['type'] == BleConstants.responseWifiList && !completer.isCompleted) {
            final nets = (json['networks'] as List)
                .map((n) => _WifiNet(
                      ssid: (n['ssid'] as String?) ?? '',
                      rssi: (n['rssi'] as int?) ?? -100,
                      isOpen: ((n['auth'] as int?) ?? 0) == 0,
                    ))
                .where((n) => n.ssid.isNotEmpty)
                .toList()
              ..sort((a, b) => b.rssi.compareTo(a.rssi));

            // Captive portal error from previous boot
            if (json['lastError'] == 'captive_portal') {
              final failedSsid = json['lastSsid'] as String?;
              if (mounted) setState(() => _lastFailedSsid = failedSsid);
            }

            completer.complete(nets);
          }
        } catch (_) {
          // Incomplete JSON — keep accumulating chunks
        }
      });

      await _rxChar!.write(utf8.encode(BleConstants.cmdScanWifi), withoutResponse: false);

      try {
        final nets = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Scan WiFi timeout'),
        );
        if (mounted) setState(() => _wifiNetworks = nets);
      } finally {
        await sub.cancel();
        await _txChar!.setNotifyValue(false).catchError((_) => false);
      }
    } on TimeoutException {
      if (mounted) setState(() => _wifiError = 'L\'ESP32 n\'a pas répondu (timeout 15 s)');
    } catch (e) {
      if (mounted) {
        setState(() => _wifiError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _wifiScanning = false);
    }
  }

  void _selectWifi(_WifiNet net) {
    setState(() {
      _selectedWifi = net;
      _ssidCtrl.text = net.ssid;
      _passCtrl.clear();
      _wifiFormError = null;
    });
  }

  // ── Provision ─────────────────────────────────────────────────────────

  Future<void> _provision() async {
    // Validate WiFi selection
    final ssid = _manualEntry
        ? _ssidCtrl.text.trim()
        : (_selectedWifi?.ssid ?? '');

    if (ssid.isEmpty) {
      setState(() => _wifiFormError = 'Sélectionnez un réseau WiFi');
      return;
    }

    final isOpen = _manualEntry ? _passCtrl.text.isEmpty : (_selectedWifi?.isOpen ?? false);
    final password = isOpen ? '' : _passCtrl.text;

    if (!isOpen && password.isEmpty) {
      setState(() => _wifiFormError = 'Mot de passe requis pour ce réseau');
      return;
    }

    setState(() {
      _step = _Step.provisioning;
      _provisionStatus = 'Connexion BLE…';
      _provisionError = null;
    });

    try {
      await _ensureBleConnected();
      _setStatus('Création de l\'appareil…');

      final macAddress = _selected!.device.remoteId.str;
      final created = await ref.read(devicesNotifierProvider.notifier).create(
            name: _nameCtrl.text.trim(),
            macAddress: macAddress,
          );
      if (created == null) throw Exception('Échec création appareil');

      _setStatus('Envoi de la configuration WiFi…');
      final payload = jsonEncode({
        'cmd': 'provision',
        'ssid': ssid,
        'password': password,
        'mqttBroker': ApiConstants.mqttBroker,
        'deviceId': created.id,
      });

      // withoutResponse: true — ESP32 restarts immediately after saving config,
      // before it can send the ATT Write Response. Using Write With Response
      // causes Android GATT_ERROR 133 because the connection drops mid-ack.
      await _rxChar!.write(utf8.encode(payload), withoutResponse: true);

      _setStatus('Configuration envoyée, redémarrage ESP32…');
      // Give ESP32 time to save NVS before we disconnect
      await Future.delayed(const Duration(milliseconds: 500));
      await _disconnectBle();

      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      await _disconnectBle();
      if (mounted) {
        setState(() {
          _step = _Step.wifiPick;
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

  void _showPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permissions requises'),
        content: const Text(
          'Les permissions Bluetooth sont bloquées.\n'
          'Activez-les dans les paramètres de l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

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
        _Step.bleScan      => _buildBleScan(),
        _Step.configure    => _buildConfigure(),
        _Step.wifiPick     => _buildWifiPick(),
        _Step.provisioning => _buildProvisioning(),
        _Step.done         => _buildDone(),
      },
    );
  }

  // ── Step 1: BLE device scan ────────────────────────────────────────────

  Widget _buildBleScan() {
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
            child: Row(children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Scan BLE en cours…'),
            ]),
          ),

        if (_found.isEmpty && !_scanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(children: [
                Icon(Icons.bluetooth_searching, size: 48),
                SizedBox(height: 8),
                Text('Aucun ESP32 trouvé'),
                SizedBox(height: 4),
                Text(
                  'Assurez-vous que l\'ESP32 est alimenté\net en mode provisioning.',
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),

        ..._found.map((r) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.developer_board)),
          title: Text(r.device.platformName),
          subtitle: Text(r.device.remoteId.str),
          trailing: Text(
            '${r.rssi} dBm',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => _selectDevice(r),
        )),

        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _scanning ? null : _startBleScan,
          icon: const Icon(Icons.refresh),
          label: const Text('Relancer le scan'),
        ),
      ],
    );
  }

  // ── Step 2: Configure (device name) ───────────────────────────────────

  Widget _buildConfigure() {
    return Form(
      key: _nameFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: _selected!.device.platformName,
            subtitle: _selected!.device.remoteId.str,
            onClose: () => setState(() => _step = _Step.bleScan),
            closeIcon: Icons.arrow_back,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _nameCtrl,
            label: "Nom de l'appareil",
            hint: 'Ex: ESP32 Salon',
            textInputAction: TextInputAction.done,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Champ requis' : null,
            onSubmitted: (_) => _goToWifiPick(),
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Suivant',
            loading: _bleConnecting,
            onPressed: _bleConnecting ? null : _goToWifiPick,
          ),
        ],
      ),
    );
  }

  void _goToWifiPick() {
    if (!_nameFormKey.currentState!.validate()) return;
    setState(() => _step = _Step.wifiPick);
    _requestWifiScan();
  }

  // ── Step 3: WiFi pick ──────────────────────────────────────────────────

  Widget _buildWifiPick() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLoading = _wifiScanning || _bleConnecting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          title: 'Réseau WiFi',
          subtitle: _nameCtrl.text,
          onClose: () => setState(() {
            _step = _Step.configure;
            _selectedWifi = null;
            _wifiNetworks = [];
            _wifiError = null;
            _wifiFormError = null;
            _manualEntry = false;
          }),
          closeIcon: Icons.arrow_back,
        ),
        const SizedBox(height: 16),

        // Errors
        if (_provisionError != null) ...[
          ErrorBanner(
            message: _provisionError!,
            onDismiss: () => setState(() => _provisionError = null),
          ),
          const SizedBox(height: 12),
        ],
        if (_wifiError != null) ...[
          ErrorBanner(
            message: _wifiError!,
            onDismiss: () => setState(() => _wifiError = null),
          ),
          const SizedBox(height: 12),
        ],
        if (_wifiFormError != null) ...[
          ErrorBanner(
            message: _wifiFormError!,
            onDismiss: () => setState(() => _wifiFormError = null),
          ),
          const SizedBox(height: 12),
        ],

        // ── Captive portal error from previous boot ──
        if (_lastFailedSsid != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi_off, size: 16, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dernière tentative échouée : "$_lastFailedSsid" utilise un portail captif. L\'ESP32 ne peut pas s\'y connecter. Choisissez un autre réseau.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _lastFailedSsid = null),
                  child: Icon(Icons.close, size: 14, color: cs.onErrorContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Loading ──
        if (isLoading && !_manualEntry)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Scan des réseaux WiFi…'),
              ],
            ),
          )

        // ── Network list ──
        else if (!_manualEntry) ...[
          if (_wifiNetworks.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _wifiNetworks.length,
                itemBuilder: (_, i) {
                  final net = _wifiNetworks[i];
                  final selected = _selectedWifi?.ssid == net.ssid;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      _signalIcon(net.bars),
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    title: Text(
                      net.ssid,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? cs.primary : null,
                      ),
                    ),
                    trailing: Icon(
                      net.isOpen ? Icons.lock_open : Icons.lock,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    selected: selected,
                    onTap: () => _selectWifi(net),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ] else if (!isLoading) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aucun réseau trouvé',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],

          // Rescan + manual entry buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : _requestWifiScan,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Rescanner'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _manualEntry = true;
                  _selectedWifi = null;
                  _ssidCtrl.clear();
                  _passCtrl.clear();
                }),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Manuel'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],

        // ── Manual entry ──
        if (_manualEntry) ...[
          AppTextField(
            controller: _ssidCtrl,
            label: 'Réseau WiFi (SSID)',
            hint: 'Nom du réseau',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() {
              _manualEntry = false;
              _ssidCtrl.clear();
              _passCtrl.clear();
            }),
            icon: const Icon(Icons.list, size: 16),
            label: const Text('Choisir depuis la liste'),
          ),
          const SizedBox(height: 8),
        ],

        // ── Password field (secured network) ──
        if (_showPasswordField) ...[
          AppTextField(
            controller: _passCtrl,
            label: _manualEntry
                ? 'Mot de passe WiFi (laisser vide si réseau ouvert)'
                : 'Mot de passe WiFi',
            obscureText: !_showPass,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
            onSubmitted: (_) => _provision(),
          ),
          const SizedBox(height: 12),
        ],

        // ── Captive portal warning ──
        if (_selectedWifi != null && _selectedWifi!.isOpen) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Réseau ouvert détecté. Si ce réseau nécessite un portail captif (hôtel, campus, bureau…), l\'ESP32 ne peut pas s\'authentifier automatiquement.\nUtilisez de préférence un hotspot personnel ou un routeur standard.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Submit ──
        if (_canSubmit)
          PrimaryButton(
            label: 'Configurer',
            onPressed: _provision,
          ),
      ],
    );
  }

  bool get _showPasswordField {
    if (_manualEntry) return true;
    return _selectedWifi != null && !_selectedWifi!.isOpen;
  }

  bool get _canSubmit {
    if (_manualEntry) return _ssidCtrl.text.isNotEmpty;
    return _selectedWifi != null;
  }

  // ── Step 4: Provisioning ───────────────────────────────────────────────

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

  // ── Step 5: Done ───────────────────────────────────────────────────────

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

  // ── Helpers ────────────────────────────────────────────────────────────

  IconData _signalIcon(int bars) => switch (bars) {
        4 => Icons.signal_wifi_4_bar,
        3 => Icons.network_wifi_3_bar,
        2 => Icons.network_wifi_2_bar,
        _ => Icons.network_wifi_1_bar,
      };
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
