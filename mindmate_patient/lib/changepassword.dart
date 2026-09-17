import 'package:flutter/material.dart';
import 'package:mindmate_patient/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PatientChangePassword extends StatefulWidget {
  const PatientChangePassword({super.key});

  @override
  State<PatientChangePassword> createState() => _PatientChangePasswordState();
}

class _PatientChangePasswordState extends State<PatientChangePassword> {
  final _passCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _updatePass() async {
    if (_passCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password too short")));
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: _passCtrl.text));

      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password Changed!")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password"), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextFormField(controller: _passCtrl, decoration: const InputDecoration(labelText: "New Password"), obscureText: true),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _loading ? null : _updatePass, child: const Text("Update Password")),
          ],
        ),
      ),
    );
  }
}