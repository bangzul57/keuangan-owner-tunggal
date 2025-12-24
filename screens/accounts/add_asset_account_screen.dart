import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/account.dart';
import '../../providers/account_provider.dart';

class AddAssetAccountScreen extends StatefulWidget {
  const AddAssetAccountScreen({super.key});

  @override
  State<AddAssetAccountScreen> createState() =>
      _AddAssetAccountScreenState();
}

class _AddAssetAccountScreenState extends State<AddAssetAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedType = 'cash';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final account = Account(
      id: const Uuid().v4().toUpperCase(),
      name: _nameController.text.trim(),
      type: 'asset',
      subType: _selectedType,
      isActive: true,
    );

    try {
      await context.read<AccountProvider>().addAccount(account);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Akun'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Akun (Kas, Dana, Bank, dll)',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Wajib diisi'
                        : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration:
                    const InputDecoration(labelText: 'Jenis Akun'),
                items: const [
                  DropdownMenuItem(
                      value: 'cash', child: Text('Kas')),
                  DropdownMenuItem(
                      value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(
                      value: 'digital',
                      child: Text('Saldo Digital')),
                ],
                onChanged: (v) =>
                    setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Simpan Akun'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
