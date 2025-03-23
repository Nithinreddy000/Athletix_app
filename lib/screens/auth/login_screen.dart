import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import '../../responsive.dart';
import '../../services/session_service.dart';
import '../main/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showEvaluatorSection = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final sessionService = context.read<SessionService>();
    if (sessionService.hasValidSession) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Get user role from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (mounted) {
          final sessionService = context.read<SessionService>();
          await sessionService.createSession(userCredential.user!);

          // Store user role in session
          if (userDoc.exists) {
            final role = userDoc.data()?['role'] ?? '';
            await sessionService.setUserRole(role);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = switch (e.code) {
            'user-not-found' => 'No user found with this email.',
            'wrong-password' => 'Wrong password provided.',
            'invalid-email' => 'Invalid email address.',
            'user-disabled' => 'This account has been disabled.',
            _ => 'An error occurred: ${e.message}',
          };
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Auto sign-in with provided credentials
  Future<void> _loginAsUser(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get user role from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (mounted) {
        final sessionService = context.read<SessionService>();
        await sessionService.createSession(userCredential.user!);

        // Store user role in session
        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? '';
          await sessionService.setUserRole(role);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'user-not-found' => 'No user found with this email.',
          'wrong-password' => 'Wrong password provided.',
          'invalid-email' => 'Invalid email address.',
          'user-disabled' => 'This account has been disabled.',
          _ => 'An error occurred: ${e.message}',
        };
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Disable back button
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Responsive(
                mobile: _buildLoginCard(context, 400),
                tablet: _buildLoginCard(context, 500),
                desktop: _buildLoginCard(context, 600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, double width) {
    return Card(
      elevation: 4,
      color: secondaryColor,
      margin: const EdgeInsets.all(defaultPadding),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsets.all(defaultPadding),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 100,
              ),
              const SizedBox(height: defaultPadding),
              if (!_showEvaluatorSection) ...[
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    prefixIcon: Icon(Icons.email, color: Colors.white70),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    prefixIcon: Icon(Icons.lock, color: Colors.white70),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: defaultPadding),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: defaultPadding),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: defaultPadding),
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: defaultPadding),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showEvaluatorSection = true;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                  child: const Text('Click here if you are an evaluator'),
                ),
              ] else ...[
                // Evaluator welcome section
                Container(
                  padding: const EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome, Evaluator!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      const Text(
                        'Select a role to access different dashboards:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      _buildUserCard(
                        'Administrator',
                        'nithinreddy3630@gmail.com',
                        '123456',
                        Icons.admin_panel_settings,
                        Colors.red,
                      ),
                      const SizedBox(height: defaultPadding / 2),
                      _buildUserCard(
                        'Medical Staff',
                        'uuknow402@gmail.com',
                        '123456',
                        Icons.medical_services,
                        Colors.green,
                      ),
                      const SizedBox(height: defaultPadding / 2),
                      _buildUserCard(
                        'Organization',
                        'managementsystemathelete@gmail.com',
                        '123456',
                        Icons.business,
                        primaryColor,
                      ),
                      const SizedBox(height: defaultPadding / 2),
                      _buildUserCard(
                        'Coach',
                        'reddynithinreddy.22@ifheindia.org',
                        '123456',
                        Icons.sports,
                        Colors.orange,
                      ),
                      const SizedBox(height: defaultPadding / 2),
                      _buildUserCard(
                        'Athlete',
                        'iamunknownunknown30@gmail.com',
                        '123456',
                        Icons.fitness_center,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: defaultPadding),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showEvaluatorSection = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                  child: const Text('Go back to normal login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(String role, String email, String password, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: secondaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        onTap: () => _loginAsUser(email, password),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding / 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.login, color: color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
