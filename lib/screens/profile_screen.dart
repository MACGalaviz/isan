import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final DatabaseService dbService;

  const ProfileScreen({
    super.key, 
    required this.user, 
    required this.dbService
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signOut();
      await widget.dbService.cleanDb();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sesión cerrada correctamente")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // AHORA SÍ: Usamos Padding igual que en tu AuthScreen
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, 
        right: 24, 
        top: 24
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Handle bar indicator (Igual al AuthScreen)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600], // Color gris para modo oscuro
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // 2. Icono (Estilo oscuro)
            const Icon(Icons.account_circle_outlined, size: 60, color: Color(0xFF2C2C2C)),
            const SizedBox(height: 16),
            
            // 3. Título
            const Text(
              "Mi Perfil",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.white // Texto blanco
              ),
            ),
            const SizedBox(height: 24),

            // 4. Input EMAIL (Solo lectura, Estilo Dark)
            TextField(
              enabled: false, 
              controller: TextEditingController(text: widget.user.email),
              style: const TextStyle(color: Colors.white70),
              decoration: const InputDecoration(
                labelText: "Email",
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 16),

            // 5. Input ID
            TextField(
              enabled: false, 
              controller: TextEditingController(text: widget.user.id),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              decoration: const InputDecoration(
                labelText: "ID de Usuario",
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.fingerprint, color: Colors.grey),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white10),
                ),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 24),

            // 6. Botón Salir
            ElevatedButton(
              onPressed: _isLoading ? null : _signOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.15),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: Colors.red.withOpacity(0.5))
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                  : const Text("Cerrar Sesión"),
            ),
            const SizedBox(height: 16),

            // 7. Botón Cancelar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
