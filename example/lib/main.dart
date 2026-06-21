import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:scout_logger_plus/scout_logger_plus.dart';

/// App API client — separate from scout's private ingest Dio.
Dio? apiDio;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Scout.initFromEnv(
    options: const ScoutOptions(
      environment: 'development',
      debug: true,
      enabledLevels: {
        ScoutLevel.error,
        ScoutLevel.warning,
        ScoutLevel.success,
        ScoutLevel.info,
      },
    ),
  );

  if (Scout.isInitialized) {
    Scout.instance.setUser(id: 'demo-user', email: 'demo@example.com', name: 'Demo User');
    apiDio = Dio(BaseOptions(baseUrl: ScoutEnv.read('API_BASE_URL') ?? 'https://httpbin.org'))
      ..attachScout();
  }

  runApp(ScoutApp(
    builder: (scoutObservers) => MaterialApp(
      navigatorObservers: scoutObservers,
      routes: {
        '/': (_) => const DemoHome(),
        '/checkout': (_) => const DemoCheckout(),
      },
      initialRoute: '/',
    ),
  ));
}

class DemoHome extends StatelessWidget {
  const DemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('scout_logger_plus')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!Scout.isInitialized)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Add SCOUT_DSN to .env to enable scout'),
              ),
            FilledButton(
              onPressed: () {
                if (!Scout.isInitialized) return;
                Scout.instance.logInfo('User opened demo');
                Scout.instance.captureException(
                  StateError('Demo payment failure'),
                  StackTrace.current,
                  category: ScoutCategory.network,
                  context: {'orderId': 'ord_123', 'step': 'checkout'},
                );
                Scout.instance.flush();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error sent — check dashboard')),
                );
              },
              child: const Text('Send test error'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/checkout'),
              child: const Text('Go to checkout (screen trail)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final dio = apiDio;
                if (dio == null) return;
                try {
                  await dio.get('/get');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API call logged — check dashboard')),
                    );
                  }
                } on DioException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('API failed: ${e.message}')),
                    );
                  }
                }
              },
              child: const Text('Call demo API (network log)'),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoCheckout extends StatelessWidget {
  const DemoCheckout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            if (Scout.isInitialized) Scout.instance.logWarning('Checkout abandoned');
            Navigator.pop(context);
          },
          child: const Text('Back'),
        ),
      ),
    );
  }
}
