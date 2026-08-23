import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _interestController = TextEditingController();

  String _gender = 'Prefer not to say';
  String _lookingFor = 'Friendship';

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.clearError();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final interests = _interestController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final success = await widget.controller.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      gender: _gender,
      lookingFor: _lookingFor,
      interests: interests,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).popUntil(
            (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Create Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 560,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        Icon(
                          Icons.favorite,
                          size: 55,
                          color: colors.secondary,
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Join Soul Finder',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'Create your profile and start discovering new connections.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                          ),
                        ),

                        const SizedBox(height: 30),

                        TextFormField(
                          controller: _nameController,
                          textCapitalization:
                          TextCapitalization.words,
                          decoration: _inputDecoration(
                            label: 'Full name',
                            icon: Icons.person_outline,
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().length < 2) {
                              return 'Please enter your full name.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _emailController,
                          keyboardType:
                          TextInputType.emailAddress,
                          decoration: _inputDecoration(
                            label: 'Email address',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            final email =
                                value?.trim() ?? '';

                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+$',
                            ).hasMatch(email)) {
                              return 'Please enter a valid email.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _ageController,
                          keyboardType:
                          TextInputType.number,
                          decoration: _inputDecoration(
                            label: 'Age',
                            icon: Icons.cake_outlined,
                          ),
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

                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: _inputDecoration(
                            label: 'Gender',
                            icon: Icons.wc_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Non-binary',
                              child: Text('Non-binary'),
                            ),
                            DropdownMenuItem(
                              value: 'Prefer not to say',
                              child:
                              Text('Prefer not to say'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _gender = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: _lookingFor,
                          decoration: _inputDecoration(
                            label: 'Looking for',
                            icon: Icons.favorite_outline,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Friendship',
                              child: Text('Friendship'),
                            ),
                            DropdownMenuItem(
                              value: 'Relationship',
                              child: Text('Relationship'),
                            ),
                            DropdownMenuItem(
                              value: 'Both',
                              child: Text(
                                'Friendship or relationship',
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _lookingFor = value;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _interestController,
                          decoration: _inputDecoration(
                            label: 'Interests',
                            icon: Icons.interests_outlined,
                            hint:
                            'Music, hiking, movies',
                          ),
                          validator: (value) {
                            if ((value ?? '')
                                .trim()
                                .isEmpty) {
                              return 'Enter at least one interest.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          decoration: _inputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hidePassword =
                                  !_hidePassword;
                                });
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons
                                    .visibility_outlined
                                    : Icons
                                    .visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final password =
                                value ?? '';

                            if (password.length < 8) {
                              return 'Password must contain at least 8 characters.';
                            }

                            if (!RegExp(r'[A-Z]')
                                .hasMatch(password) ||
                                !RegExp(r'[0-9]')
                                    .hasMatch(password)) {
                              return 'Use at least one uppercase letter and one number.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller:
                          _confirmPasswordController,
                          obscureText:
                          _hideConfirmPassword,
                          decoration: _inputDecoration(
                            label: 'Confirm password',
                            icon:
                            Icons.lock_reset_outlined,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword =
                                  !_hideConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _hideConfirmPassword
                                    ? Icons
                                    .visibility_outlined
                                    : Icons
                                    .visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value !=
                                _passwordController.text) {
                              return 'Passwords do not match.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        if (widget.controller.errorMessage !=
                            null)
                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.error
                                  .withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.error
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.controller
                                        .errorMessage!,
                                    style: TextStyle(
                                      color: colors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed:
                            widget.controller.isBusy
                                ? null
                                : _register,
                            style: FilledButton.styleFrom(
                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                  16,
                                ),
                              ),
                            ),
                            child: widget.controller.isBusy
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFF1E293B),
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
    );
  }
}