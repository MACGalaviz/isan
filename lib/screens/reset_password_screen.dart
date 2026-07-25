import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/security/key_manager_service.dart';
import 'package:isan/services/database_service.dart';

/// Shown after the user opens a password-reset email link
/// (AuthChangeEvent.passwordRecovery). Sets a new account password and
/// unlocks the notes with the recovery phrase, then re-wraps the UMK so the
/// new password works on future logins.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _wordCount = 12;

  final _passwordController = TextEditingController();
  final List<TextEditingController> _wordControllers =
      List.generate(_wordCount, (_) => TextEditingController());
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    for (final c in _wordControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Splits a full pasted phrase across the individual slots.
  void _distributePasted(String value, int startIndex) {
    final words = value
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length <= 1) return; // single word → leave as typed

    for (var i = 0; i < words.length && startIndex + i < _wordCount; i++) {
      _wordControllers[startIndex + i].text = words[i];
    }
    setState(() {});
  }

  String _buildPhrase() => _wordControllers
      .map((c) => c.text.trim().toLowerCase())
      .where((w) => w.isNotEmpty)
      .join(' ');

  Future<void> _submit() async {
    final newPassword = _passwordController.text.trim();
    final phrase = _buildPhrase();

    if (newPassword.isEmpty || phrase.split(' ').length != _wordCount) {
      _showError("Fill in the new password and all 12 recovery words.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Set the new account password
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));

      // 2. Unlock the UMK with the recovery phrase
      final ok = await KeyManagerService.instance
          .recoverWithPhrase(recoveryPhrase: phrase);
      if (!ok) {
        _showError("Invalid recovery phrase.");
        setState(() => _isLoading = false);
        return;
      }

      // 3. Re-wrap the UMK under the new password + pull notes
      await KeyManagerService.instance
          .rewrapPasswordSlot(password: newPassword);
      await DatabaseService().syncFromCloud();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated. Notes unlocked.")),
        );
      }
    } catch (e) {
      _showError("Reset failed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static const _columns = 3;

  Widget _wordSlot(int index) {
    return TextField(
      controller: _wordControllers[index],
      textInputAction:
          index == _wordCount - 1 ? TextInputAction.done : TextInputAction.next,
      onChanged: (value) {
        if (value.contains(RegExp(r'\s'))) _distributePasted(value, index);
      },
      decoration: InputDecoration(
        isDense: true,
        prefixText: '${index + 1}. ',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// 12 slots laid out as a fixed 3-column grid (3 × 4).
  Widget _wordGrid() {
    final rows = (_wordCount / _columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < _columns; col++) ...[
                  Expanded(child: _wordSlot(row * _columns + col)),
                  if (col < _columns - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Reset password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Set a new password and enter your 12-word recovery phrase to "
                "unlock your notes.",
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "New password",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text("Recovery phrase", style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                "Tip: paste the whole phrase into the first box to auto-fill.",
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _wordGrid(),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Update password"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
