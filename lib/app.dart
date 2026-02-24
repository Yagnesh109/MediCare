import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:medicare_app/screens/add_medicine_screen.dart';
import 'package:medicare_app/screens/adherence_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:medicare_app/screens/home_screen.dart';
import 'package:medicare_app/screens/side_effect_checker_screen.dart';
import 'package:medicare_app/services/notification_service.dart';
import 'screens/caregivers_screen.dart';
import 'screens/profile_screen.dart';

Future<UserCredential> _signInWithGoogle() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
  await googleSignIn.signOut();

  final GoogleSignInAccount? account = await googleSignIn.signIn();
  if (account == null) {
    throw FirebaseAuthException(
      code: 'aborted-by-user',
      message: 'Google sign-in was cancelled.',
    );
  }

  final GoogleSignInAuthentication auth = await account.authentication;
  if (auth.idToken == null) {
    throw FirebaseAuthException(
      code: 'missing-id-token',
      message:
          'Missing Google ID token. Verify SHA-1/SHA-256 and Firebase config.',
    );
  }

  final OAuthCredential credential = GoogleAuthProvider.credential(
    idToken: auth.idToken,
    accessToken: auth.accessToken,
  );
  return FirebaseAuth.instance.signInWithCredential(credential);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String routeLogin = '/login';
  static const String routeHome = '/home';
  static const String routeAddMedicine = '/add_medicine';
  static const String routeSignup = '/signup';
  static const String routeCaregivers = '/caregivers';
  static const String routeProfile = '/profile';
  static const String routeAdherence = '/adherence';
  static const String routeSideEffects = '/side_effects';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medicare',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF42A5F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5FAFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFF0F4F8),
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB3D3F2)),
          ),
        ),
      ),
      home: const _AuthGate(),
      routes: {
        routeLogin: (context) => const LoginScreen(),
        routeHome: (context) => const HomeScreen(),
        routeAddMedicine: (context) => const AddMedicineScreen(),
        routeSignup: (context) => const SignupScreen(),
        routeCaregivers: (context) => const CaregiversScreen(),
        routeProfile: (context) => const ProfileScreen(),
        routeAdherence: (context) => const AdherenceScreen(),
        routeSideEffects: (context) => const SideEffectCheckerScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _lastInitUid;
  bool _isInitRunning = false;

  Future<void> _ensureNotificationInit(User user) async {
    if (_isInitRunning || _lastInitUid == user.uid) {
      return;
    }
    _isInitRunning = true;
    try {
      await NotificationService.instance.init();
      _lastInitUid = user.uid;
    } catch (_) {
      // Keep auth flow alive even if notification init fails.
    } finally {
      _isInitRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: SizedBox.expand(),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _lastInitUid = null;
          return const LoginScreen();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureNotificationInit(user);
        });
        return const HomeScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initNotificationsAfterAuth() async {
    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoginLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _initNotificationsAfterAuth();
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, MyApp.routeHome);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoginLoading = false);
      }
    }
  }

  Future<void> _onGooglePressed() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _signInWithGoogle();
      await _initNotificationsAfterAuth();
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, MyApp.routeHome);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message ?? 'Google sign-in failed (${e.code})')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.medication_rounded,
                          color: Color(0xFF1565C0),
                          size: 54,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Medicare Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Manage your medication reminders',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _isLoginLoading ? null : _onLoginPressed,
                          child: _isLoginLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isGoogleLoading ? null : _onGooglePressed,
                          icon: _isGoogleLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: Color(0xFF1565C0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, MyApp.routeSignup);
                          },
                          child: const Text(
                            "Don't have an account? Register",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSignupLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _initNotificationsAfterAuth() async {
    try {
      await NotificationService.instance.init();
    } catch (_) {}
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSignupLoading = true);
    try {
      final UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (_nameController.text.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(_nameController.text.trim());
      }
      await _initNotificationsAfterAuth();
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        MyApp.routeHome,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Sign up failed')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSignupLoading = false);
      }
    }
  }

  Future<void> _onGooglePressed() async {
    setState(() => _isGoogleLoading = true);
    try {
      await _signInWithGoogle();
      await _initNotificationsAfterAuth();
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        MyApp.routeHome,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message ?? 'Google sign-in failed (${e.code})')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.medication_rounded,
                          color: Color(0xFF1565C0),
                          size: 54,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Create Medicare Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign up to start medication reminders',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _isSignupLoading ? null : _onSignupPressed,
                          child: _isSignupLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Create Account'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isGoogleLoading ? null : _onGooglePressed,
                          icon: _isGoogleLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: Color(0xFF1565C0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              MyApp.routeLogin,
                            );
                          },
                          child: const Text('Already have an account? Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
