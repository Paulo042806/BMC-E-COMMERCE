
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;

  final Color gold = const Color(0xFFF3B943);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegister) {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': _nameController.text.trim(),
          },
        );

        if (!mounted) return;

        if (response.session != null) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _isRegister = false);
          _showMessage(
            'Account created! Check your email to confirm your account, then log in.',
          );
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;

        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Something went wrong. Please try again.');
      debugPrint('AUTH ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter your email address first.');
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      _showMessage('Password reset instructions sent if the account exists.');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      debugPrint('PASSWORD RESET ERROR: $e');
      _showMessage('Could not request a password reset. Try again.');
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: gold),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: gold, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Create Account' : 'Customer Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.sports_baseball,
                    size: 64,
                    color: gold,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CUE HAVEN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegister
                        ? 'Create your customer account'
                        : 'Sign in to continue to checkout',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  if (_isRegister) ...[
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        'Full name',
                        Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your full name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _decoration(
                      'Email address',
                      Icons.email_outlined,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _decoration(
                      'Password',
                      Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                  ),

                  if (_isRegister) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: _decoration(
                        'Confirm password',
                        Icons.lock_reset,
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                  ],

                  if (!_isRegister)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),

                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isRegister ? 'REGISTER' : 'LOGIN',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isRegister = !_isRegister;
                            });
                          },
                    child: Text(
                      _isRegister
                          ? 'Already have an account? Login'
                          : "Don't have an account? Register",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
