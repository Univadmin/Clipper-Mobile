import 'package:flutter/material.dart';
import '../services/ocr.dart';

class ScanReviewSheet extends StatefulWidget {
  const ScanReviewSheet({
    required this.result,
    required this.onSave,
    super.key,
  });
  final ScanResult result;
  final Future<bool> Function(String name, int slot) onSave;
  @override
  State<ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends State<ScanReviewSheet> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.result.seriesName;
  late int _slot = widget.result.slot;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(_name.trim(), _slot);
      if (saved && mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Okunan bilgileri kontrol et',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Seri adı veya parça numarası yanlışsa kaydetmeden önce düzeltebilirsin.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _name,
            enabled: !_saving,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Seri / model adı',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _name = value,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Seri adını gir' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _slot,
            decoration: const InputDecoration(
              labelText: 'Sahip olduğun parça',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              4,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}/4')),
            ),
            onChanged: _saving
                ? null
                : (value) => setState(() => _slot = value!),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(_saving ? 'Kaydediliyor…' : 'Koleksiyona ekle'),
          ),
        ],
      ),
    ),
  );
}
