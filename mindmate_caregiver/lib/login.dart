import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Ensure you have this import
import 'package:mindmate_caregiver/caregiver_registartion.dart';
import 'package:mindmate_caregiver/homepage.dart';
import 'package:mindmate_caregiver/main.dart'; // Assuming supabase client is initialized here

class CaregiverLoginScreen extends StatefulWidget {
  const CaregiverLoginScreen({super.key});

  @override
  State<CaregiverLoginScreen> createState() => _CaregiverLoginScreenState();
}

class _CaregiverLoginScreenState extends State<CaregiverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false; 

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Authenticate with Supabase Auth
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        throw "Login failed. Please check your credentials.";
      }

      // 2. Check Role & Status in 'tbl_caregiver'
      final data = await supabase
          .from('tbl_caregiver')
          .select()
          .eq('caregiver_email', email)
          .maybeSingle(); 

      if (data == null) {
        // User is in Auth but NOT in caregiver table
        await supabase.auth.signOut();
        throw "Access Denied: You are not registered as a Caregiver.";
      }

      // --- STATUS CHECK LOGIC ---
      final int status = data['caregiver_status'] ?? 0; // Default to 0 if null

      if (status == 0) {
        // PENDING
        await supabase.auth.signOut();
        throw "Your account is Pending approval. Please wait for Admin verification.";
      } else if (status == 2) {
        // BLOCKED
        await supabase.auth.signOut();
        throw "Your account has been Blocked. Please contact support.";
      } else if (status != 1) {
        // UNKNOWN STATUS
        await supabase.auth.signOut();
        throw "Invalid account status. Please contact Admin.";
      }

      // IF STATUS IS 1 (Active) -> Proceed to Home
      if (mounted) {
        logActivity("Login Success", "Caregiver authenticated via email: $email");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Successful!"), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CaregiverHomeScreen()),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- LOGO & WELCOME ---
                    const Icon(Icons.memory, size: 80, color: Colors.teal),
                    const SizedBox(height: 16),
                    const Text(
                      "Welcome Back!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const Text(
                      "Login to continue monitoring your patients.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 40),

                    // --- EMAIL FIELD ---
                    TextFormField(
                      controller: _emailController,
                      validator: (val) => val!.isEmpty ? "Email is required" : null,
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- PASSWORD FIELD ---
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      validator: (val) => val!.isEmpty ? "Password is required" : null,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),

                    // --- FORGOT PASSWORD ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.teal)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- LOGIN BUTTON ---
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login, // Disable if loading
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      // Show Spinner if loading, else show Text
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),

                    // --- REGISTER LINK ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ", style: TextStyle(color: Colors.grey)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CaregiverRegistrationScreen()),
                            );
                          },
                          child: const Text(
                            "Register",
                            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}