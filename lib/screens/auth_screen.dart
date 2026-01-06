import 'package:flutter/material.dart';
import 'package:isan/services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? errorMessage;

    if (_isLogin) {
      errorMessage = await _authService.signIn(email: email, password: password);
    } else {
      errorMessage = await _authService.signUp(email: email, password: password);
    }

    setState(() => _isLoading = false);

    if (errorMessage != null) {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } else {
      // Success
      if (mounted) {
        // CLOSE THE MODAL instead of navigating
        Navigator.of(context).pop(); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Success!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using Padding instead of Scaffold for better Modal integration
    return Padding(
      // Add padding for keyboard visibility (avoid obstruction)
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, 
        right: 24, 
        top: 24
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const Icon(Icons.lock_person_outlined, size: 60, color: Colors.black87),
            const SizedBox(height: 16),
            
            Text(
              _isLogin ? "Welcome Back" : "Create Account",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isLogin ? "Login" : "Sign Up"),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
              child: Text(
                _isLogin 
                ? "Don't have an account? Sign Up" 
                : "Already have an account? Login"
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
