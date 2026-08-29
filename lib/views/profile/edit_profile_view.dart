import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/auth_controller.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({
    super.key,
    required this.controller,
  });

  final AuthController controller;
  @override
  State<EditProfileView> createState() =>
      _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _bioController;
  late final TextEditingController _interestsController;

  late String _gender;
  late String _lookingFor;
  late double _radius;

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

    _interestsController = TextEditingController(
      text: user.interests.join(', '),
    );

    _gender = user.gender;
    _lookingFor = user.lookingFor;
    _radius = (user.discoveryRadius * 1000).clamp(10.0, 200.0); // Convert km to m for UI
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
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 900,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      _profileImageBytes = bytes;
      _profileImageBase64 = base64Encode(bytes);
    });
  }

  void _removeProfilePicture() {
    setState(() {
      _profileImageBytes = null;
      _profileImageBase64 = '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final current = widget.controller.currentUser!;

    final updated = current.copyWith(
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      gender: _gender,
      bio: _bioController.text.trim(),
      interests: _interestsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      lookingFor: _lookingFor,
      discoveryRadius: _radius / 1000, // Convert m back to km for storage
      profileImageBase64: _profileImageBase64,
    );

    final success =
    await widget.controller.updateProfile(updated);

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.controller.errorMessage ??
                'Unable to update profile.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            40,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildProfilePicture(theme),
                const SizedBox(height: 28),
                _buildSectionCard(
                  title: 'Personal Information',
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
                    _buildDropdown(
                      label: 'Looking For',
                      icon: Icons.favorite_border,
                      value: _lookingFor,
                      items: const [
                        'Friendship',
                        'Relationship',
                        'Both',
                      ],
                      displayValues: const {
                        'Friendship': 'Friendship',
                        'Relationship': 'Relationship',
                        'Both':
                        'Friendship or relationship',
                      },
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _lookingFor = value;
                          });
                        }
                      },
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
                      icon: Icons.notes_outlined,
                      maxLines: 4,
                      maxLength: 150,
                      hintText:
                      'Tell others about yourself...',
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Please enter a short bio.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _interestsController,
                      label: 'Interests',
                      icon: Icons.interests_outlined,
                      hintText:
                      'Music, Travel, Movies, Gaming',
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter at least one interest.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Separate interests using commas',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  title: 'Discovery Settings',
                  icon: Icons.radar_outlined,
                  theme: theme,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Discovery Radius',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primary
                                .withOpacity(0.12),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_radius.round()} m',
                            style: TextStyle(
                              color: theme.primary,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _radius,
                      min: 10,
                      max: 200,
                      divisions: 19, // 10m increments
                      label: '${_radius.round()} m',
                      onChanged: (value) {
                        setState(() {
                          _radius = value;
                        });
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Text(
                            '10 m',
                            style: TextStyle(
                              color: Colors.white38,
                            ),
                          ),
                          Text(
                            '200 m',
                            style: TextStyle(
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed:
                    widget.controller.isBusy
                        ? null
                        : _save,
                    icon: widget.controller.isBusy
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.check_circle_outline,
                    ),
                    label: Text(
                      widget.controller.isBusy
                          ? 'Saving...'
                          : 'Save Changes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(18),
                      ),
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

  Widget _buildProfilePicture(
      ColorScheme theme,
      ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.primary,
                    theme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 65,
                backgroundColor:
                const Color(0xFF1E293B),
                backgroundImage:
                _profileImageBytes != null
                    ? MemoryImage(
                  _profileImageBytes!,
                )
                    : null,
                child: _profileImageBytes == null
                    ? const Icon(
                  Icons.person,
                  size: 65,
                  color: Colors.white54,
                )
                    : null,
              ),
            ),
            InkWell(
              onTap: _pickProfilePicture,
              borderRadius:
              BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0F172A),
                    width: 4,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 21,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Profile Picture',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Tap the camera icon to upload a photo',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
        ),
        if (_profileImageBytes != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _removeProfilePicture,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
            ),
            label: const Text(
              'Remove Photo',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required ColorScheme theme,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: theme.primary
                      .withOpacity(0.12),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType =
        TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF3B82F6),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
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
    String? safeValue;

    if (items.contains(value)) {
      safeValue = value;
    }

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF3B82F6),
            width: 1.5,
          ),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            displayValues?[item] ?? item,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}