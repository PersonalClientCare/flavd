import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "../providers/device_provider.dart";
import "../services/avd_service.dart";
import "../widgets/qr_painter_widget.dart";

/// Screen for pairing and connecting to a physical Android device over
/// wireless ADB (Android 11+ wireless debugging).
///
/// Step 1 offers two pairing modes via a [SegmentedButton]:
///   - **Manual** – type in IP, port, and pairing code.
///   - **QR Code** – enter the same details, then display a scannable QR code
///     that the phone can read via "Pair device with QR code".
///
/// Step 2 (Connect) is always the same regardless of how pairing was done.
class WirelessAdbScreen extends StatefulWidget {
  const WirelessAdbScreen({super.key});

  @override
  State<WirelessAdbScreen> createState() => _WirelessAdbScreenState();
}

/// The two pairing modes available in Step 1.
enum _PairMode { manual, qr }

class _WirelessAdbScreenState extends State<WirelessAdbScreen> {
  // --- Pair mode toggle ---
  _PairMode _pairMode = _PairMode.manual;

  // --- Manual pair form ---
  final _pairFormKey = GlobalKey<FormState>();
  final _pairHostController = TextEditingController();
  final _pairPortController = TextEditingController();
  final _pairCodeController = TextEditingController();
  bool _pairing = false;
  String? _pairResult;
  bool _pairSuccess = false;

  // --- QR pair form ---
  final _qrFormKey = GlobalKey<FormState>();
  final _qrHostController = TextEditingController();
  final _qrPortController = TextEditingController();
  final _qrCodeController = TextEditingController();
  final _qrPasswordController = TextEditingController();
  final _qrServiceNameController = TextEditingController(
    text: "adb-flavd-pair",
  );
  bool _qrGenerated = false;
  bool _qrPairing = false;
  String? _qrPairResult;
  bool _qrPairSuccess = false;

  // --- Connect form ---
  final _connectFormKey = GlobalKey<FormState>();
  final _connectHostController = TextEditingController();
  final _connectPortController = TextEditingController(text: "5555");
  bool _connecting = false;
  String? _connectResult;
  bool _connectSuccess = false;

  @override
  void dispose() {
    _pairHostController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    _qrHostController.dispose();
    _qrPortController.dispose();
    _qrCodeController.dispose();
    _qrPasswordController.dispose();
    _qrServiceNameController.dispose();
    _connectHostController.dispose();
    _connectPortController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // QR payload
  // ---------------------------------------------------------------------------

  /// Builds the `WIFI:T:ADB;S:<name>;P:<password>;;` string that Android's
  /// "Pair device with QR code" feature expects.
  String _buildQrPayload() {
    final service = _qrServiceNameController.text.trim().isNotEmpty
        ? _qrServiceNameController.text.trim()
        : "adb-flavd-pair";
    final password = _qrPasswordController.text.trim();
    return "WIFI:T:ADB;S:$service;P:$password;;";
  }

  // ---------------------------------------------------------------------------
  // Manual pair
  // ---------------------------------------------------------------------------

  Future<void> _submitPair(DeviceProvider provider) async {
    if (!_pairFormKey.currentState!.validate()) return;

    setState(() {
      _pairing = true;
      _pairResult = null;
    });

    try {
      final result = await provider.pairDevice(
        host: _pairHostController.text.trim(),
        port: int.parse(_pairPortController.text.trim()),
        code: _pairCodeController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _pairResult = result;
          _pairSuccess = true;
        });
      }
    } on AvdException catch (e) {
      if (mounted) {
        setState(() {
          _pairResult = e.message;
          _pairSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pairResult = e.toString();
          _pairSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // QR pair – after the phone scans the QR code, pair via adb
  // ---------------------------------------------------------------------------

  Future<void> _submitQrPair(DeviceProvider provider) async {
    if (!_qrFormKey.currentState!.validate()) return;

    setState(() {
      _qrPairing = true;
      _qrPairResult = null;
    });

    try {
      final result = await provider.pairDevice(
        host: _qrHostController.text.trim(),
        port: int.parse(_qrPortController.text.trim()),
        code: _qrCodeController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _qrPairResult = result;
          _qrPairSuccess = true;
        });
      }
    } on AvdException catch (e) {
      if (mounted) {
        setState(() {
          _qrPairResult = e.message;
          _qrPairSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrPairResult = e.toString();
          _qrPairSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _qrPairing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Connect
  // ---------------------------------------------------------------------------

  Future<void> _submitConnect(DeviceProvider provider) async {
    if (!_connectFormKey.currentState!.validate()) return;

    setState(() {
      _connecting = true;
      _connectResult = null;
    });

    try {
      final result = await provider.connectDevice(
        host: _connectHostController.text.trim(),
        port: int.parse(_connectPortController.text.trim()),
      );
      if (mounted) {
        setState(() {
          _connectResult = result;
          _connectSuccess = true;
        });
      }
    } on AvdException catch (e) {
      if (mounted) {
        setState(() {
          _connectResult = e.message;
          _connectSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectResult = e.toString();
          _connectSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wireless ADB")),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instructions
                const _InstructionsBanner(),
                const SizedBox(height: 24),

                // ---- Step 1 header ----
                const _SectionHeader(
                  icon: Icons.phonelink_lock,
                  title: "Step 1: Pair (first time only)",
                ),
                const SizedBox(height: 12),

                // ---- Pairing mode toggle ----
                Center(
                  child: SegmentedButton<_PairMode>(
                    segments: const [
                      ButtonSegment(
                        value: _PairMode.manual,
                        icon: Icon(Icons.keyboard, size: 18),
                        label: Text("Manual"),
                      ),
                      ButtonSegment(
                        value: _PairMode.qr,
                        icon: Icon(Icons.qr_code, size: 18),
                        label: Text("QR Code"),
                      ),
                    ],
                    selected: {_pairMode},
                    onSelectionChanged: (selection) {
                      setState(() => _pairMode = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Pairing content (animated crossfade) ----
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _pairMode == _PairMode.manual
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _buildManualPairSection(context, provider),
                  secondChild: _buildQrPairSection(context, provider),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // ---- Step 2: Connect ----
                const _SectionHeader(
                  icon: Icons.wifi,
                  title: "Step 2: Connect",
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter the IP address and port shown on the Wireless "
                  "debugging screen (not the pairing port). For legacy "
                  "connections (adb tcpip 5555), use port 5555.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _ConnectForm(
                  formKey: _connectFormKey,
                  hostController: _connectHostController,
                  portController: _connectPortController,
                  connecting: _connecting,
                  onSubmit: () => _submitConnect(provider),
                ),
                if (_connectResult != null) ...[
                  const SizedBox(height: 12),
                  _ResultChip(
                    message: _connectResult!,
                    isSuccess: _connectSuccess,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Manual pair section
  // ---------------------------------------------------------------------------

  Widget _buildManualPairSection(
    BuildContext context,
    DeviceProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "On your phone go to Settings → Developer options → Wireless "
          "debugging → Pair device with pairing code. Enter the IP "
          "address, pairing port, and 6-digit code shown on the phone.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _PairForm(
          formKey: _pairFormKey,
          hostController: _pairHostController,
          portController: _pairPortController,
          codeController: _pairCodeController,
          pairing: _pairing,
          onSubmit: () => _submitPair(provider),
        ),
        if (_pairResult != null) ...[
          const SizedBox(height: 12),
          _ResultChip(message: _pairResult!, isSuccess: _pairSuccess),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // QR pair section
  // ---------------------------------------------------------------------------

  Widget _buildQrPairSection(BuildContext context, DeviceProvider provider) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Generate a QR code your phone can scan via Settings → Developer "
          "options → Wireless debugging → Pair device with QR code.\n\n"
          "Fill in the password (pairing code from your phone) and "
          "optionally a service name, then tap \"Generate QR Code\". "
          "After the phone confirms pairing, tap \"Complete Pairing\" below "
          "to register the device with ADB.",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // --- QR generation form ---
        Form(
          key: _qrFormKey,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _qrPasswordController,
                      decoration: const InputDecoration(
                        labelText: "Password / Pairing Code",
                        hintText: "482924",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Required";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _qrServiceNameController,
                      decoration: const InputDecoration(
                        labelText: "Service Name",
                        hintText: "adb-flavd-pair",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    if (_qrFormKey.currentState!.validate()) {
                      setState(() => _qrGenerated = true);
                    }
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text("Generate QR Code"),
                ),
              ),
            ],
          ),
        ),

        // --- QR code display ---
        if (_qrGenerated) ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrPainterWidget(
                    data: _buildQrPayload(),
                    size: 220,
                    moduleColor: scheme.onSurface,
                    backgroundColor: scheme.surface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Scan this with your phone's\n\"Pair device with QR code\"",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _buildQrPayload(),
                  style: TextStyle(
                    fontFamily: "monospace",
                    fontSize: 11,
                    color: scheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- After phone confirms, complete pairing via adb ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "After the phone confirms pairing",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter the phone's IP address, pairing port, and the "
                  "pairing code so ADB on this computer registers the device.",
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _qrHostController,
                        decoration: const InputDecoration(
                          labelText: "IP Address",
                          hintText: "192.168.1.42",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.computer),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qrPortController,
                        decoration: const InputDecoration(
                          labelText: "Pairing Port",
                          hintText: "37755",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qrCodeController,
                        decoration: const InputDecoration(
                          labelText: "Pairing Code",
                          hintText: "482924",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pin),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _qrPairing
                        ? null
                        : () => _submitQrPair(provider),
                    icon: _qrPairing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_qrPairing ? "Pairing…" : "Complete Pairing"),
                  ),
                ),
              ],
            ),
          ),
          if (_qrPairResult != null) ...[
            const SizedBox(height: 12),
            _ResultChip(message: _qrPairResult!, isSuccess: _qrPairSuccess),
          ],
        ],
      ],
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _InstructionsBanner extends StatelessWidget {
  const _InstructionsBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Prerequisites",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "1. Your phone must have Developer options enabled.\n"
                  "2. Enable Wireless debugging (Android 11+).\n"
                  "3. Both your phone and this computer must be on the "
                  "same Wi-Fi network.\n"
                  "4. For phones below Android 11, connect via USB first "
                  "and run 'adb tcpip 5555', then use Step 2 (Connect) only.",
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _PairForm extends StatelessWidget {
  const _PairForm({
    required this.formKey,
    required this.hostController,
    required this.portController,
    required this.codeController,
    required this.pairing,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController codeController;
  final bool pairing;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: "IP Address",
                    hintText: "192.168.1.42",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                  validator: _validateHost,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: portController,
                  decoration: const InputDecoration(
                    labelText: "Pairing Port",
                    hintText: "37755",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePort,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: "Pairing Code",
                    hintText: "482924",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Required";
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: pairing ? null : onSubmit,
              icon: pairing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.phonelink_lock),
              label: Text(pairing ? "Pairing…" : "Pair"),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ConnectForm extends StatelessWidget {
  const _ConnectForm({
    required this.formKey,
    required this.hostController,
    required this.portController,
    required this.connecting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool connecting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: "IP Address",
                    hintText: "192.168.1.42",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.computer),
                  ),
                  validator: _validateHost,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: portController,
                  decoration: const InputDecoration(
                    labelText: "Port",
                    hintText: "5555",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePort,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: connecting ? null : onSubmit,
              icon: connecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi),
              label: Text(connecting ? "Connecting…" : "Connect"),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bgColor = isSuccess
        ? scheme.tertiaryContainer
        : scheme.errorContainer;
    final fgColor = isSuccess
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: fgColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fgColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared validators
// ---------------------------------------------------------------------------

String? _validateHost(String? v) {
  if (v == null || v.trim().isEmpty) return "Required";
  // Basic IPv4 check – also allow hostnames.
  final trimmed = v.trim();
  final ipv4 = RegExp(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$");
  final hostname = RegExp(r"^[a-zA-Z0-9._-]+$");
  if (!ipv4.hasMatch(trimmed) && !hostname.hasMatch(trimmed)) {
    return "Enter a valid IP address or hostname";
  }
  return null;
}

String? _validatePort(String? v) {
  if (v == null || v.trim().isEmpty) return "Required";
  final n = int.tryParse(v.trim());
  if (n == null || n < 1 || n > 65535) return "1–65535";
  return null;
}
