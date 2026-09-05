import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth_controller.dart';
import '../../models/interest_data.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _bioController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  late List<String> _selectedInterests;

  final Map<String, String> _interestMapping = {
    'Pet Lovers': 'pet_lovers',
    'Tech Enthusiasts': 'tech_enthusiasts',
    'Travelers': 'travelers',
    'Music': 'music',
    'Gaming': 'gaming',
    'Movies': 'movies',
    'Fitness': 'fitness',
    'Foodie': 'foodie',
    'Art': 'art',
    'Photography': 'photography',
    'Sports': 'sports',
    'Cooking': 'cooking',
  };

  List<String> get _predefinedInterests => _interestMapping.keys.toList();

  late String _gender;

  Uint8List? _profileImageBytes;
  String _profileImageBase64 = '';

  @override
  void initState() {
    super.initState();

    final user = widget.controller.currentUser!;

    _nameController = TextEditingController(
      text: user.name,
    );

    _ageController = TextEditingController(
      text: user.age.toString(),
    );

    _bioController = TextEditingController(
      text: user.bio,
    );

    _heightController = TextEditingController(
      text: user.heightCm != null ? user.heightCm!.toStringAsFixed(0) : '',
    );

    _weightController = TextEditingController(
      text: user.weightKg != null ? user.weightKg!.toStringAsFixed(0) : '',
    );

    _selectedInterests = user.interests.map((raw) {
      return _interestMapping.entries
          .firstWhere((e) => e.value == raw, orElse: () => MapEntry(raw, raw))
          .key;
    }).toList();

    _gender = user.gender;
    _profileImageBase64 = user.profileImageBase64;

    if (_profileImageBase64.isNotEmpty) {
      try {
        _profileImageBytes =
            base64Decode(_profileImageBase64);
      } catch (_) {
        _profileImageBytes = null;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        _profileImageBytes = bytes;
        _profileImageBase64 = base64String;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showImagePickerSheet(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ImagePickerOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                _ImagePickerOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final current = widget.controller.currentUser!;

    final double? heightVal = double.tryParse(_heightController.text.trim());
    final double? weightVal = double.tryParse(_weightController.text.trim());

    final updated = current.copyWith(
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      gender: _gender,
      bio: _bioController.text.trim(),
      interests: _selectedInterests.map((name) => _interestMapping[name] ?? name).toList(),
      lookingFor: current.lookingFor,
      discoveryRadius: current.discoveryRadius,
      profileImageBase64: _profileImageBase64,
      heightCm: heightVal,
      weightKg: weightVal,
    );

    final success =
    await widget.controller.updateProfile(updated);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ??
                'Failed to update profile.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: widget.controller.isBusy
                ? null
                : _saveProfile,
            child: widget.controller.isBusy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildAvatarSection(theme),
                const SizedBox(height: 24),
                _buildSectionCard(
                  title: 'Basic Info',
                  icon: Icons.person_outline,
                  theme: theme,
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.badge_outlined,
                      validator: (value) {
                        if ((value ?? '').trim().length < 2) {
                          return 'Please enter your name.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final age =
                        int.tryParse(value ?? '');

                        if (age == null ||
                            age < 18 ||
                            age > 100) {
                          return 'Age must be between 18 and 100.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Gender',
                      icon: Icons.wc_outlined,
                      value: _gender,
                      items: const [
                        'Male',
                        'Female',
                        'Non-binary',
                        'Prefer not to say',
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _gender = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _heightController,
                            label: 'Height (cm)',
                            icon: Icons.height,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              final val = value?.trim();
                              if (val == null || val.isEmpty) return null;
                              final numVal = double.tryParse(val);
                              if (numVal == null || numVal < 50 || numVal > 250) {
                                return 'Enter 50-250 cm';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _weightController,
                            label: 'Weight (kg)',
                            icon: Icons.monitor_weight_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (value) {
                              final val = value?.trim();
                              if (val == null || val.isEmpty) return null;
                              final numVal = double.tryParse(val);
                              if (numVal == null || numVal < 20 || numVal > 300) {
                                return 'Enter 20-300 kg';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'About Me',
                  icon: Icons.auto_awesome_outlined,
                  theme: theme,
                  children: [
                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      icon: null,
                      maxLines: 4,
                      maxLength: 250,
                      hintText:
                      'Tell others a bit about yourself...',
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Need inspiration? Tap a template to apply:',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        '✈️ Coffee lover & weekend explorer',
                        '🚀 Tech enthusiast & music addict',
                        '🏋️ Fitness lover & foodie at heart',
                        '🎨 Creative soul exploring new places',
                      ].map((template) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
                          label: Text(template, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          backgroundColor: const Color(0xFF0F172A),
                          onPressed: () {
                            setState(() {
                              _bioController.text = template;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Interests',
                  icon: Icons.interests_outlined,
                  theme: theme,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _predefinedInterests
                          .map((interest) {
                        final isSelected =
                        _selectedInterests.contains(
                          interest,
                        );

                        return FilterChip(
                          label: Text(interest),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedInterests.add(
                                  interest,
                                );
                              } else {
                                _selectedInterests
                                    .remove(
                                  interest,
                                );
                              }
                            });
                          },
                          selectedColor: theme
                              .colorScheme.primary
                              .withValues(
                            alpha: 0.25,
                          ),
                          checkmarkColor: theme
                              .colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor:
                          theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.white12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: widget.controller.isBusy
                      ? null
                      : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                    const Size.fromHeight(52),
                    backgroundColor:
                    theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: theme.colorScheme.surface,
            backgroundImage: _profileImageBytes != null
                ? MemoryImage(_profileImageBytes!)
                : null,
            child: _profileImageBytes == null
                ? Icon(
              Icons.person,
              size: 58,
              color: theme.colorScheme.primary,
            )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: () => _showImagePickerSheet(theme),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required ThemeData theme,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    Map<String, String>? displayValues,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(displayValues?[item] ?? item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _ImagePickerOption extends StatelessWidget {
  const _ImagePickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
