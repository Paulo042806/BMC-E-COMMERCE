
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/product_list_screen.dart';
import 'screens/admin_dashboard_screen.dart';

const gold = Color(0xFFF3B943);
const dark = Color(0xFF090B0D);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CueHavenBootstrap());
}

class CueHavenBootstrap extends StatefulWidget {
  const CueHavenBootstrap({super.key});

  @override
  State<CueHavenBootstrap> createState() => _CueHavenBootstrapState();
}

class _CueHavenBootstrapState extends State<CueHavenBootstrap> {
  bool initialized = false;
  bool initializing = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  Future<void> initializeApp() async {
    if (initializing) return;

    setState(() {
      initializing = true;
      errorMessage = null;
    });

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );

      if (!mounted) return;

      setState(() {
        initialized = true;
        initializing = false;
      });
    } catch (e, stackTrace) {
      debugPrint('SUPABASE INITIALIZATION ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        initializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (initialized) {
      return const CueHavenApp();
    }

    return MaterialApp(
      title: 'Cue Haven',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: errorMessage != null
          ? StartupErrorScreen(
              message: errorMessage!,
              onRetry: initializeApp,
            )
          : const StartupScreen(),
    );
  }
}

class CueHavenApp extends StatelessWidget {
  const CueHavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cue Haven',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: dark,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const RoleRouter(),
    );
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: dark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_bar, color: gold, size: 64),
            SizedBox(height: 20),
            Text(
              'CUE HAVEN',
              style: TextStyle(
                color: gold,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: gold),
            SizedBox(height: 12),
            Text(
              'Initializing application...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const StartupErrorScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to Start Cue Haven',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: gold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Supabase initialization failed. Check the error below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              SelectableText(
                message,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  SupabaseClient get supabase => Supabase.instance.client;

  bool loading = true;
  bool isAdmin = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    checkRole();

    supabase.auth.onAuthStateChange.listen((_) {
      checkRole();
    });
  }

  Future<void> checkRole() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          isAdmin = false;
          loading = false;
        });
        return;
      }

      final result = await supabase
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      setState(() {
        isAdmin = result?['role'] == 'admin';
        loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Role check error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'Unable to verify your account role. Check connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: dark,
        body: Center(
          child: CircularProgressIndicator(color: gold),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: dark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: checkRole,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isAdmin) {
      return const AdminDashboardScreen();
    }

    return const ProductListScreen();
  }
}
