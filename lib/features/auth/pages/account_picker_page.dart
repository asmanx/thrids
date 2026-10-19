import 'package:flutter/material.dart';

import 'package:thrids/services/api_service.dart';

import '../../pages/widgets/user_avatar.dart';
import 'login_page.dart';

class AccountPickerPage extends StatefulWidget {
  /// Daftar akun yang sudah diunduh saat splash (opsional). Kalau ada, langsung
  /// ditampilkan, lalu tetap disegarkan di latar belakang.
  final List<Map<String, dynamic>>? initialUsers;

  const AccountPickerPage({super.key, this.initialUsers});

  static const background = Color(0xFF1F1F1F);
  static const cardColor = Color(0xFF171717);
  static const mutedText = Color(0xFF858585);

  @override
  State<AccountPickerPage> createState() => _AccountPickerPageState();
}

class _AccountPickerPageState extends State<AccountPickerPage> {
  late List<Map<String, dynamic>> users = widget.initialUsers ?? [];
  late bool isLoading = widget.initialUsers == null;
  String? errorMessage;

  /// Diganti setiap daftar dimuat ulang, supaya foto profil yang baru diganti
  /// tidak tertahan di cache gambar.
  int _stamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    fetchUsers(silent: widget.initialUsers != null);
  }

  /// [silent] = true: tidak menampilkan loading / error kalau sudah ada daftar.
  Future<void> fetchUsers({bool silent = false}) async {
    try {
      final result = await ApiService.getUsers();

      if (!mounted) return;

      setState(() {
        users = result;
        isLoading = false;
        errorMessage = null;
        _stamp = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (error) {
      if (!mounted) return;

      // Sudah ada daftar yang tampil: biarkan saja, jangan diganti pesan error.
      if (silent && users.isNotEmpty) return;

      setState(() {
        isLoading = false;
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// URL foto profil akun, atau null kalau belum punya foto.
  String? _photoUrl(Map<String, dynamic> user) {
    final raw =
        (user['profile_picture'] ?? user['avatar_url'] ?? '').toString().trim();

    if (raw.isEmpty) return null;

    final url = ApiService.resolveUrl(raw);

    // Hanya foto di server sendiri yang diberi penanda versi.
    if (!url.startsWith(ApiService.serverUrl)) return url;

    return '$url${url.contains('?') ? '&' : '?'}v=$_stamp';
  }

  Future<void> _openLogin({String? username}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginPage(username: username)),
    );

    // Kembali dari login / register: segarkan daftar (foto, akun baru).
    if (mounted) fetchUsers(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountPickerPage.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            const Text(
              '@ thrids',
              style: TextStyle(
                color: Colors.white,
                fontSize: 43,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -2,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Pilih akun untuk melanjutkan',
              style: TextStyle(
                color: AccountPickerPage.mutedText,
                fontSize: 15,
              ),
            ),

            const Spacer(flex: 2),

            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Builder(
                  builder: (context) {
                    if (isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (errorMessage != null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AccountPickerPage.mutedText,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AccountPickerPage.mutedText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });
                                fetchUsers();
                              },
                              child: const Text(
                                'Coba lagi',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (users.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada akun terdaftar.',
                          style: TextStyle(color: AccountPickerPage.mutedText),
                        ),
                      );
                    }

                    // Tarik ke bawah untuk memuat ulang daftar akun & foto.
                    return RefreshIndicator(
                      onRefresh: () => fetchUsers(silent: true),
                      color: Colors.white,
                      backgroundColor: AccountPickerPage.cardColor,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final user = users[index];

                          final username = user['username']?.toString() ?? '';
                          final displayName =
                              user['display_name']?.toString() ?? username;

                          return _accountCard(
                            username: username,
                            displayName: displayName,
                            photoUrl: _photoUrl(user),
                            // Login memakai username, jadi kolom langsung terisi.
                            onTap: () => _openLogin(username: username),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            TextButton(
              onPressed: () => _openLogin(),
              child: const Text(
                'Gunakan profil lain',
                style: TextStyle(
                  color: AccountPickerPage.mutedText,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Foto profil bulat. Kalau belum ada / gagal dimuat, tampil avatar bawaan
  /// (siluet abu-abu) seperti akun lain, bukan huruf awal.
  Widget _avatar(String username, String? photoUrl) {
    const size = 54.0;

    if (photoUrl == null) return const UserAvatar(size: size);

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const UserAvatar(size: size),
        errorBuilder: (_, _, _) => const UserAvatar(size: size),
      ),
    );
  }

  Widget _accountCard({
    required String username,
    required String displayName,
    required String? photoUrl,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AccountPickerPage.cardColor,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            children: [
              _avatar(username, photoUrl),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AccountPickerPage.mutedText,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AccountPickerPage.mutedText,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}