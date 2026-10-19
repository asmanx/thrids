import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/username_rules.dart';
import '../../../services/api_service.dart';
import '../../../services/username_service.dart';
import '../../pages/home_page.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final usernameController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  // Pemeriksaan username (aturan + ketersediaan)
  UsernameStatus usernameStatus = UsernameStatus.idle;
  String? usernameMessage;
  List<String> usernameSuggestions = [];
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    usernameController.dispose();
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // REGISTER / MEMBUAT AKUN
  Future<void> _register() async {
    final username = UsernameRules.normalize(usernameController.text);
    final name = nameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || name.isEmpty || password.isEmpty) {
      _showMessage('Semua kolom wajib diisi.');
      return;
    }

    final usernameError = UsernameRules.validate(username);

    if (usernameError != null) {
      _showMessage(usernameError);
      return;
    }

    if (usernameStatus == UsernameStatus.taken) {
      _showMessage('Username sudah dipakai.');
      return;
    }

    if (name.length > 100) {
      _showMessage('Nama tampilan maksimal 100 karakter.');
      return;
    }

    if (password.length < 8) {
      _showMessage('Password minimal 8 karakter.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.register(
        username: username,
        displayName: name,
        password: password,
      );

      final token = response['token'];
      final user = response['user'];

      if (token == null || token.toString().isEmpty) {
        throw Exception('Token tidak ditemukan. Periksa respons backend.');
      }

      if (user == null || user is! Map) {
        throw Exception('Data akun tidak ditemukan.');
      }

      if (!mounted) return;

      // Langsung masuk beranda setelah registrasi berhasil.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            token: token.toString(),
            user: Map<String, dynamic>.from(user),
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      // Username diambil orang lain tepat sebelum kamu menekan "Buat akun".
      if (message.toLowerCase().contains('sudah dipakai')) {
        setState(() {
          usernameStatus = UsernameStatus.taken;
          usernameMessage = message;
        });
        _onUsernameChanged(usernameController.text);
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // MENAMPILKAN PESAN
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        title: const Text('Buat akun'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Bergabung dengan Thrids',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Buat akun dan mulai berbagi ceritamu.',
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 30),

              _usernameField(),
              _usernameStatusView(),

              const SizedBox(height: 14),

              _field(
                nameController,
                'Nama tampilan',
                icon: Icons.badge_outlined,
              ),

              const SizedBox(height: 14),

              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _decoration(
                      'Password (minimal 8 karakter)',
                      Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54,
                        ),
                      ),
                    ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: (isLoading || usernameStatus == UsernameStatus.taken)
                      ? null
                      : _register,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Buat akun',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sudah punya akun?',
                    style: TextStyle(color: Colors.white70),
                  ),

                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                    child: const Text(
                      'Masuk',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // USERNAME: aturan Threads + cek ketersediaan
  void _onUsernameChanged(String raw) {
    _usernameDebounce?.cancel();

    final username = UsernameRules.normalize(raw);

    if (username.isEmpty) {
      setState(() {
        usernameStatus = UsernameStatus.idle;
        usernameMessage = null;
        usernameSuggestions = [];
      });
      return;
    }

    final error = UsernameRules.validate(username);

    if (error != null) {
      setState(() {
        usernameStatus = UsernameStatus.invalid;
        usernameMessage = error;
        usernameSuggestions = [];
      });
      return;
    }

    setState(() {
      usernameStatus = UsernameStatus.checking;
      usernameMessage = null;
      usernameSuggestions = [];
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await UsernameService.check(username);

        // Abaikan hasil lama kalau pengguna sudah mengetik lagi.
        if (!mounted ||
            UsernameRules.normalize(usernameController.text) != username) {
          return;
        }

        setState(() {
          if (!result.valid) {
            usernameStatus = UsernameStatus.invalid;
          } else {
            usernameStatus = result.available
                ? UsernameStatus.available
                : UsernameStatus.taken;
          }
          usernameMessage = result.message.isEmpty ? null : result.message;
          usernameSuggestions =
              (result.valid && !result.available) ? result.suggestions : [];
        });
      } catch (_) {
        // Gagal memeriksa (mis. tidak ada koneksi): jangan blokir pendaftaran,
        // server tetap memeriksa lagi saat akun dibuat.
        if (!mounted) return;
        setState(() {
          usernameStatus = UsernameStatus.idle;
          usernameMessage = null;
          usernameSuggestions = [];
        });
      }
    });
  }

  Widget _usernameField() {
    return TextField(
      controller: usernameController,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: UsernameRules.inputFormatters,
      onChanged: _onUsernameChanged,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration('Username', Icons.person_outline),
    );
  }

  void _pickSuggestion(String suggestion) {
    usernameController.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    _onUsernameChanged(suggestion);
  }

  Widget _usernameStatusView() {
    const green = Color(0xFF4CAF50);
    const red = Color(0xFFFF5A5F);

    var color = Colors.white54;
    var text = UsernameRules.hint;
    Widget? leading;

    switch (usernameStatus) {
      case UsernameStatus.idle:
        break;
      case UsernameStatus.checking:
        text = 'Memeriksa username…';
        leading = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        );
        break;
      case UsernameStatus.available:
        color = green;
        text = usernameMessage ?? 'Username tersedia.';
        leading = const Icon(Icons.check_circle_outline, size: 16, color: green);
        break;
      case UsernameStatus.taken:
        color = red;
        text = usernameMessage ?? 'Username sudah dipakai.';
        leading = const Icon(Icons.error_outline, size: 16, color: red);
        break;
      case UsernameStatus.invalid:
        color = red;
        text = usernameMessage ?? 'Username tidak sesuai aturan.';
        leading = const Icon(Icons.error_outline, size: 16, color: red);
        break;
    }

    final statusRow = Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(padding: const EdgeInsets.only(top: 1), child: leading),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        statusRow,
        if (usernameStatus == UsernameStatus.taken &&
            usernameSuggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Coba:',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                for (final suggestion in usernameSuggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => _pickSuggestion(suggestion),
                    backgroundColor: const Color(0xFF171717),
                    side: const BorderSide(color: Color(0xFF353535)),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // INPUT TEXT
  Widget _field(
    TextEditingController controller,
    String hint, {
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint, icon),
    );
  }

  // DESAIN INPUT
  InputDecoration _decoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF171717),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}