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

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      // 1. Clear encryption keys
      await KeyManagerService.instance.logout();
      
      // 2. Clear local database
      await widget.dbService.cleanDb();
      
      // 3. Sign out from Supabase
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
            // Handle bar
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

            // Email (readonly)
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

            // User ID
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

            // Sign out (destructive)
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