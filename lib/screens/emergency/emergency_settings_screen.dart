import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_settings.dart';

class EmergencySettingsScreen extends StatefulWidget {
  final List<EmergencyContact> emergencyContacts;
  final EmergencySettings emergencySettings;
  final EmergencyService emergencyService;
  final Function(List<EmergencyContact>, EmergencySettings) onSave;

  const EmergencySettingsScreen({
    Key? key,
    required this.emergencyContacts,
    required this.emergencySettings,
    required this.emergencyService,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EmergencySettingsScreen> createState() =>
      _EmergencySettingsScreenState();
}

class _EmergencySettingsScreenState extends State<EmergencySettingsScreen> {
  late List<EmergencyContact> contacts;
  late EmergencySettings settings;
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emergencyNumberController = TextEditingController();
  final searchController = TextEditingController();

  bool hasUnsavedChanges = false;
  List<Contact> phoneContacts = [];
  List<Contact> filteredContacts = [];
  bool isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    contacts = List.from(widget.emergencyContacts);
    settings = widget.emergencySettings.copyWith();
    emergencyNumberController.text = settings.emergencyServiceNumber;
  }

  void markAsChanged() {
    if (!hasUnsavedChanges) setState(() => hasUnsavedChanges = true);
  }

  Future<void> requestContactsPermission() async {
    final permission = await FlutterContacts.requestPermission();
    if (permission) {
      await loadPhoneContacts();
    } else {
      showPermissionDialog();
    }
  }

  Future<void> loadPhoneContacts() async {
    setState(() => isLoadingContacts = true);
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        phoneContacts =
            contacts
                .where((c) => c.phones.isNotEmpty && c.displayName.isNotEmpty)
                .toList()
              ..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              );
        filteredContacts = List.from(phoneContacts);
        isLoadingContacts = false;
      });
    } catch (e) {
      setState(() => isLoadingContacts = false);
      showSnackBar('Error loading contacts: $e', Colors.red.shade400);
    }
  }

  void filterContacts(String query) {
    setState(() {
      filteredContacts =
          query.isEmpty
              ? List.from(phoneContacts)
              : phoneContacts
                  .where(
                    (c) =>
                        c.displayName.toLowerCase().contains(
                          query.toLowerCase(),
                        ) ||
                        c.phones.any(
                          (p) => p.number
                              .replaceAll(RegExp(r'[^\d+]'), '')
                              .contains(query),
                        ),
                  )
                  .toList();
    });
  }

  void showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Contacts Permission Required',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: const Text(
              'Grant contacts permission to import contacts from your phone.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  requestContactsPermission();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void showContactImportDialog() async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      await requestContactsPermission();
      return;
    }

    if (phoneContacts.isEmpty) await loadPhoneContacts();
    searchController.clear();
    filteredContacts = List.from(phoneContacts);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Import from Contacts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Search contacts',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onChanged: (value) {
                              filterContacts(value);
                              setState(() {});
                            },
                          ),
                        ),
                        Expanded(
                          child:
                              isLoadingContacts
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : filteredContacts.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'No contacts found',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: filteredContacts.length,
                                    itemBuilder: (context, index) {
                                      final contact = filteredContacts[index];
                                      return buildContactItem(
                                        contact,
                                        setState,
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget buildContactItem(Contact contact, StateSetter setState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            contact.displayName[0].toUpperCase(),
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          contact.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${contact.phones.length} phone number(s)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        children:
            contact.phones.map((phone) {
              final phoneNumber = phone.number.replaceAll(
                RegExp(r'[^\d+]'),
                '',
              );
              final isAdded = contacts.any((c) => c.phoneNumber == phoneNumber);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(
                    phoneNumber,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    phone.label.toString(),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing:
                      isAdded
                          ? Icon(
                            Icons.check_circle,
                            color: Colors.green.shade400,
                          )
                          : IconButton(
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              addContactFromPhone(
                                contact.displayName,
                                phoneNumber,
                              );
                              setState(() {});
                            },
                          ),
                ),
              );
            }).toList(),
      ),
    );
  }

  void addContactFromPhone(String name, String phoneNumber) {
    if (contacts.any((c) => c.phoneNumber == phoneNumber)) {
      showSnackBar('Contact already exists', Colors.orange.shade400);
      return;
    }

    setState(() {
      contacts.add(
        EmergencyContact(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          phoneNumber: phoneNumber,
          priority: contacts.length + 1,
          sendLocationSMS: true,
        ),
      );
      markAsChanged();
    });
    showSnackBar('$name added to emergency contacts', Colors.green.shade400);
  }

  void showAddContactDialog() {
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Add Emergency Contact',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        prefixText: '',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        if (contacts.any(
                          (c) => c.phoneNumber == value.trim(),
                        )) {
                          return 'This phone number already exists';
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
                onPressed: () {
                  nameController.clear();
                  phoneController.clear();
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    setState(() {
                      contacts.add(
                        EmergencyContact(
                          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          phoneNumber: phone,
                          priority: contacts.length + 1,
                          sendLocationSMS: true,
                        ),
                      );
                      markAsChanged();
                    });

                    nameController.clear();
                    phoneController.clear();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  void editContact(EmergencyContact contact) {
    nameController.text = contact.name;
    phoneController.text = contact.phoneNumber;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final currentContact = contacts.firstWhere(
                (c) => c.id == contact.id,
              );

              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Edit Contact',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Name *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            prefixText: '',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            if (contacts.any(
                              (c) =>
                                  c.phoneNumber == value.trim() &&
                                  c.id != contact.id,
                            )) {
                              return 'This phone number already exists';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: SwitchListTile(
                            title: const Text('Send Location SMS'),
                            value: currentContact.sendLocationSMS,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              final index = contacts.indexWhere(
                                (c) => c.id == contact.id,
                              );
                              if (index != -1) {
                                setState(() {
                                  contacts[index] = contacts[index].copyWith(
                                    sendLocationSMS: value,
                                  );
                                  markAsChanged();
                                });
                                setDialogState(() {});
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      nameController.clear();
                      phoneController.clear();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final name = nameController.text.trim();
                        final phone = phoneController.text.trim();

                        setState(() {
                          final index = contacts.indexWhere(
                            (c) => c.id == contact.id,
                          );
                          if (index != -1) {
                            contacts[index] = contacts[index].copyWith(
                              name: name,
                              phoneNumber: phone,
                            );
                            markAsChanged();
                          }
                        });

                        nameController.clear();
                        phoneController.clear();
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void deleteContact(EmergencyContact contact) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Contact',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Remove "${contact.name}" from emergency contacts?',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    contacts.removeWhere((c) => c.id == contact.id);
                    for (int i = 0; i < contacts.length; i++) {
                      contacts[i] = contacts[i].copyWith(priority: i + 1);
                    }
                    markAsChanged();
                  });
                  showSnackBar('${contact.name} removed', Colors.red.shade400);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void reorderContacts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final contact = contacts.removeAt(oldIndex);
      contacts.insert(newIndex, contact);
      for (int i = 0; i < contacts.length; i++) {
        contacts[i] = contacts[i].copyWith(priority: i + 1);
      }
      markAsChanged();
    });
  }

  void updateSetting<T>(
    T value,
    T Function(EmergencySettings) getter,
    EmergencySettings Function(T) updater,
  ) {
    if (getter(settings) != value) {
      setState(() {
        settings = updater(value);
        markAsChanged();
      });
    }
  }

  void showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> saveSettings() async {
    final emergencyNumber = emergencyNumberController.text.trim();
    if (emergencyNumber.isNotEmpty) {
      settings = settings.copyWith(emergencyServiceNumber: emergencyNumber);
    }

    try {
      widget.onSave(contacts, settings);
      setState(() => hasUnsavedChanges = false);
      showSnackBar('Settings saved successfully', Colors.green.shade400);
    } catch (e) {
      showSnackBar(
        'Error saving settings. Please try again.',
        Colors.red.shade400,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (hasUnsavedChanges) {
          final result = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    'Unsaved Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  content: const Text(
                    'You have unsaved changes. Save before leaving?',
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Discard',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await saveSettings();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save & Exit',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          );
          return result ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.primary,
          surfaceTintColor: Colors.white,
          title: const Text(
            'Emergency Contacts',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: saveSettings,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.save,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  tooltip: 'Save Changes',
                ),
              ),
          ],
        ),

        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildContactsSection(),
                  const SizedBox(height: 16),
                  buildSettingsSection(),
                ],
              ),
            ),
            if (hasUnsavedChanges)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: saveSettings,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text(
                        'Save All Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Contacts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${contacts.length} contacts added',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    SizedBox(
                      width: 100,
                      child: ElevatedButton.icon(
                        onPressed: showContactImportDialog,
                        icon: const Icon(Icons.contacts, size: 16),
                        label: const Text(
                          'Import',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: ElevatedButton.icon(
                        onPressed: showAddContactDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Add',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (contacts.isEmpty) _buildEmptyState() else _buildContactsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.contacts_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts added yet',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add contacts who should be notified during emergencies',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contacts.length,
      onReorder: reorderContacts,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactCard(contact);
      },
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Container(
      key: ValueKey(contact.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              '${contact.priority}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact.phoneNumber,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
            if (contact.sendLocationSMS)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ), // Reduced padding
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 10, // Reduced from 12
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Location SMS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: SizedBox(
          width: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => editContact(contact),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.blue.shade400,
                    size: 18,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => deleteContact(contact),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 18,
                  ),
                ),
              ),
              Icon(Icons.drag_handle, color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            buildSettingTile(
              'Auto-send location to all contacts',
              'Automatically share your location with emergency contacts',
              settings.autoSendLocationToAll,
              (value) => updateSetting(
                value,
                (s) => s.autoSendLocationToAll,
                (v) => settings.copyWith(autoSendLocationToAll: v),
              ),
            ),
            buildSettingTile(
              'Play alert sound',
              'Play an audible alert during emergencies',
              settings.playAlertSound,
              (value) => updateSetting(
                value,
                (s) => s.playAlertSound,
                (v) => settings.copyWith(playAlertSound: v),
              ),
            ),
            buildSettingTile(
              'Auto-call emergency services',
              'Automatically call emergency services when triggered',
              settings.autoCallEmergencyServices,
              (value) => updateSetting(
                value,
                (s) => s.autoCallEmergencyServices,
                (v) => settings.copyWith(autoCallEmergencyServices: v),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                title: const Text(
                  'Call timeout',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Duration before timing out emergency calls',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<int>(
                    value: settings.callTimeoutSeconds,
                    underline: const SizedBox(),
                    items:
                        [15, 30, 45, 60]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text('${s}s'),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) =>
                            value != null
                                ? updateSetting(
                                  value,
                                  (s) => s.callTimeoutSeconds,
                                  (v) =>
                                      settings.copyWith(callTimeoutSeconds: v),
                                )
                                : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            buildEmergencyNumberSection(),
          ],
        ),
      ),
    );
  }

  Widget buildEmergencyNumberSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: Colors.red.shade400, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Emergency Service Number',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Phone number for local emergency services',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emergencyNumberController,
              decoration: InputDecoration(
                hintText: 'e.g., 911, 999, 112',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (_) => markAsChanged(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSettingTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emergencyNumberController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
