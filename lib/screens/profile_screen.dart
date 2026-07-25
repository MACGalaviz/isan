import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/services/security/key_manager_service.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final DatabaseService dbService;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.dbService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  /// Changes the account password while keeping the UMK reachable.
  ///
  /// The current password is not needed to re-wrap the UMK (it already lives in
  /// the session) — it is an authorization check, so holding an unlocked device
  /// isn't enough to take over the account.
  Future<void> _changePassword() async {
    final result = await showDialog<({String current, String newPassword})>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      // 1. Verify the current password against the cloud-wrapped UMK
      final ok = await KeyManagerService.instance
          .loginWithPassword(password: result.current);
      if (!ok) {
        _showMessage("Current password is wrong (or no connection)");
        return;
      }

      // 2. Change the Supabase credential FIRST. If step 3 then fails, the
      // recovery phrase still opens the account. The reverse order would leave
      // the UMK wrapped under a password Supabase doesn't know about.
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: result.newPassword));

      // 3. Re-wrap the UMK so the new password unlocks notes on other devices
      try {
        await KeyManagerService.instance
            .rewrapPasswordSlot(password: result.newPassword);
      } catch (e) {
        debugPrint("❌ Re-wrap failed after password change: $e");
        await _showKeySyncFailure();
        return;
      }

      _showMessage("Password updated");
    } catch (e) {
      _showMessage("Couldn't change password: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Step 3 failed: the account password changed but the key slot didn't.
  /// Loud on purpose — logging out now means needing the recovery phrase.
  Future<void> _showKeySyncFailure() {
    if (!mounted) return Future.value();

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Keys not re-synced"),
        content: const Text(
          "Your password changed, but your encryption keys were not updated. "
          "Retry the password change before logging out — otherwise you'll "
          "need your recovery phrase to open your notes again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await KeyManagerService.instance.logout();
      
      await widget.dbService.cleanDb();
      
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logged out successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Icon(
              Icons.account_circle_outlined,
              size: 60,
              color: colors.primary,
            ),
            const SizedBox(height: 16),

            Text(
              "Profile",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),

            TextField(
              readOnly: true,
              controller: TextEditingController(text: widget.user.email),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Email",
                prefixIcon: const Icon(Icons.email_outlined),
                fillColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              readOnly: true,
              controller: TextEditingController(text: widget.user.id),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "User ID",
                prefixIcon: const Icon(Icons.fingerprint),
                fillColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : _changePassword,
              icon: const Icon(Icons.key_outlined),
              label: const Text("Change password"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _signOut,
              style: ElevatedButton.styleFrom(
                foregroundColor: colors.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: colors.error),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onSurface,
                      ),
                    )
                  : const Text("Log out"),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Collects and validates the three fields. Pops with the passwords or null.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  static const _minLength = 6;

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final current = _currentController.text;
    final newPassword = _newController.text;

    if (current.isEmpty) {
      setState(() => _error = "Enter your current password");
      return;
    }
    if (newPassword.length < _minLength) {
      setState(() => _error = "New password needs $_minLength+ characters");
      return;
    }
    if (newPassword != _confirmController.text) {
      setState(() => _error = "Passwords don't match");
      return;
    }

    Navigator.pop(context, (current: current, newPassword: newPassword));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Change password"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: "Current password"),
          ),
          TextField(
            controller: _newController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "New password"),
          ),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Confirm new password",
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(onPressed: _submit, child: const Text("Change")),
      ],
    );
  }
}