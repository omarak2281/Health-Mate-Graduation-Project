import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/medical_contacts_provider.dart';

class MedicalContactsPage extends ConsumerWidget {
  const MedicalContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicalContactsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medical Contacts')),
      body: state.isLoading && state.contacts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.contacts.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.contacts.length,
              itemBuilder: (context, index) {
                final contact = state.contacts[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(
                        contact.type,
                      ).withValues(alpha: 0.1),
                      child: Icon(
                        _getTypeIcon(contact.type),
                        color: _getTypeColor(contact.type),
                      ),
                    ),
                    title: Text(contact.name),
                    subtitle: Text(contact.phone),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.call,
                            color: AppColors.success,
                          ),
                          onPressed: () => _makePhoneCall(contact.phone),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppColors.error,
                          ),
                          onPressed: () =>
                              _confirmDelete(context, ref, contact.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContactDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_phone_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No contacts yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Add doctors, pharmacies, or emergency numbers'),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedType = 'doctor';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                items: const [
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'pharmacy', child: Text('Pharmacy')),
                  DropdownMenuItem(
                    value: 'emergency',
                    child: Text('Emergency'),
                  ),
                  DropdownMenuItem(value: 'family', child: Text('Family')),
                ],
                onChanged: (value) => setState(() => selectedType = value!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty) {
                  ref
                      .read(medicalContactsNotifierProvider.notifier)
                      .addContact(
                        nameController.text,
                        phoneController.text,
                        selectedType,
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: const Text('Are you sure you want to delete this contact?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(medicalContactsNotifierProvider.notifier).deleteContact(id);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'doctor':
        return Icons.medical_services;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'emergency':
        return Icons.local_hospital;
      case 'family':
        return Icons.people;
      default:
        return Icons.person;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'doctor':
        return Colors.blue;
      case 'pharmacy':
        return Colors.green;
      case 'emergency':
        return Colors.red;
      case 'family':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
