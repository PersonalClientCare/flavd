import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/api_level.dart';
import '../models/form_factor.dart';
import '../providers/device_provider.dart';
import '../widgets/log_output_widget.dart';

/// Screen for creating a new Android Virtual Device.
class CreateDeviceScreen extends StatefulWidget {
  const CreateDeviceScreen({super.key});

  @override
  State<CreateDeviceScreen> createState() => _CreateDeviceScreenState();
}

class _CreateDeviceScreenState extends State<CreateDeviceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _widthController = TextEditingController(text: '1080');
  final _heightController = TextEditingController(text: '1920');
  final _densityController = TextEditingController(text: '420');

  ApiLevel _selectedApiLevel = ApiLevel.supported.first;
  FormFactor _selectedFormFactor = FormFactor.phone;
  String _selectedAbi = 'x86_64';
  String _selectedTag = 'google_apis';

  bool _creating = false;

  static const _abiOptions = ['x86_64', 'x86', 'arm64-v8a', 'armeabi-v7a'];
  static const _tagOptions = [
    'google_apis',
    'google_apis_playstore',
    'default',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _densityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Virtual Device')),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----- Device name -----
                  _SectionTitle(title: 'Device Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. My_Pixel_Device',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a device name.';
                      }
                      if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(v.trim())) {
                        return 'Only letters, numbers, underscores, hyphens and dots are allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ----- API Level -----
                  _SectionTitle(title: 'API Level'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ApiLevel>(
                    value: _selectedApiLevel,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: ApiLevel.supported
                        .map((l) => DropdownMenuItem(
                              value: l,
                              child: Text(l.toString()),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedApiLevel = v);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ----- Form Factor -----
                  _SectionTitle(title: 'Form Factor'),
                  const SizedBox(height: 8),
                  _FormFactorGrid(
                    selected: _selectedFormFactor,
                    onSelected: (f) => setState(() => _selectedFormFactor = f),
                  ),

                  // ----- Custom size fields -----
                  if (_selectedFormFactor.isCustom) ...[
                    const SizedBox(height: 16),
                    _CustomSizeFields(
                      widthController: _widthController,
                      heightController: _heightController,
                      densityController: _densityController,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ----- Advanced -----
                  _AdvancedSection(
                    selectedAbi: _selectedAbi,
                    selectedTag: _selectedTag,
                    abiOptions: _abiOptions,
                    tagOptions: _tagOptions,
                    onAbiChanged: (v) {
                      if (v != null) setState(() => _selectedAbi = v);
                    },
                    onTagChanged: (v) {
                      if (v != null) setState(() => _selectedTag = v);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ----- Log output -----
                  LogOutputWidget(lines: provider.logLines),
                  if (provider.logLines.isNotEmpty) const SizedBox(height: 16),

                  // ----- Create button -----
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _creating ? null : () => _submit(provider),
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle_outline),
                      label: Text(_creating ? 'Creating…' : 'Create Device'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit(DeviceProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _creating = true);

    final ok = await provider.createDevice(
      name: _nameController.text.trim(),
      apiLevel: _selectedApiLevel.level,
      formFactor: _selectedFormFactor,
      customWidth:
          _selectedFormFactor.isCustom ? int.tryParse(_widthController.text) : null,
      customHeight:
          _selectedFormFactor.isCustom ? int.tryParse(_heightController.text) : null,
      customDensity:
          _selectedFormFactor.isCustom ? int.tryParse(_densityController.text) : null,
      tag: _selectedTag,
      abi: _selectedAbi,
    );

    if (mounted) {
      setState(() => _creating = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device created successfully!')),
        );
        Navigator.of(context).pop();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ---------------------------------------------------------------------------

class _FormFactorGrid extends StatelessWidget {
  const _FormFactorGrid({required this.selected, required this.onSelected});

  final FormFactor selected;
  final ValueChanged<FormFactor> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FormFactor.presets.map((f) {
        final isSelected = selected.name == f.name;
        return ChoiceChip(
          label: Text(f.name),
          selected: isSelected,
          avatar: Icon(_iconForFormFactor(f), size: 18),
          onSelected: (_) => onSelected(f),
        );
      }).toList(),
    );
  }

  IconData _iconForFormFactor(FormFactor f) {
    if (f.isCustom) return Icons.tune;
    if (f.name.contains('Tablet')) return Icons.tablet_android;
    if (f.name.contains('TV')) return Icons.tv;
    if (f.name.contains('Wear')) return Icons.watch;
    if (f.name.contains('Foldable')) return Icons.tablet_android;
    return Icons.smartphone;
  }
}

// ---------------------------------------------------------------------------

class _CustomSizeFields extends StatelessWidget {
  const _CustomSizeFields({
    required this.widthController,
    required this.heightController,
    required this.densityController,
  });

  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController densityController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Display Settings',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: widthController,
                label: 'Width (px)',
                hint: '1080',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                controller: heightController,
                label: 'Height (px)',
                hint: '1920',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                controller: densityController,
                label: 'Density (dpi)',
                hint: '420',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        final n = int.tryParse(v ?? '');
        if (n == null || n <= 0) return 'Enter a positive integer.';
        return null;
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _AdvancedSection extends StatefulWidget {
  const _AdvancedSection({
    required this.selectedAbi,
    required this.selectedTag,
    required this.abiOptions,
    required this.tagOptions,
    required this.onAbiChanged,
    required this.onTagChanged,
  });

  final String selectedAbi;
  final String selectedTag;
  final List<String> abiOptions;
  final List<String> tagOptions;
  final ValueChanged<String?> onAbiChanged;
  final ValueChanged<String?> onTagChanged;

  @override
  State<_AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<_AdvancedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  'Advanced Options',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.selectedAbi,
                  decoration: const InputDecoration(
                    labelText: 'ABI',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.abiOptions
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: widget.onAbiChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.selectedTag,
                  decoration: const InputDecoration(
                    labelText: 'System Image Tag',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.tagOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: widget.onTagChanged,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
