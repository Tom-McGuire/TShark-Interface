import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'models/launch_adapter_config.dart';
import 'services/shared_device_database.dart';
import 'ui/theme/app_theme.dart';
import 'ui/views/capture_home_screen.dart';
import 'view_models/tshark_capture_view_model.dart';

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();
  final launchAdapterConfig = LaunchAdapterConfig.fromArgs(args);
  final initialMode = await SharedDeviceDatabase.instance.getThemeMode();
  AppTheme.isDark = (initialMode == 'dark');

  runApp(TSharkInterfaceApp(launchAdapterConfig: launchAdapterConfig));
}

class TSharkInterfaceApp extends StatefulWidget {
  const TSharkInterfaceApp({
    super.key,
    this.launchAdapterConfig,
    this.sharedDatabase,
    this.viewModel,
  });

  final LaunchAdapterConfig? launchAdapterConfig;
  final SharedDeviceDatabase? sharedDatabase;
  final TSharkCaptureViewModel? viewModel;

  @override
  State<TSharkInterfaceApp> createState() => _TSharkInterfaceAppState();
}

class _TSharkInterfaceAppState extends State<TSharkInterfaceApp> {
  StreamSubscription<void>? _dbSub;
  String _themeMode = AppTheme.isDark ? 'dark' : 'light';

  SharedDeviceDatabase get _db =>
      widget.sharedDatabase ?? SharedDeviceDatabase.instance;

  @override
  void initState() {
    super.initState();
    _syncTheme();
    _dbSub = _db.onDatabaseChanged.listen((_) {
      _syncTheme();
    });
  }

  Future<void> _syncTheme() async {
    final mode = await _db.getThemeMode();
    if (!mounted) return;
    if (mode != _themeMode || (mode == 'dark') != AppTheme.isDark) {
      setState(() {
        _themeMode = mode;
        AppTheme.isDark = (mode == 'dark');
      });
    }
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'T-Shark Interface',
      debugShowCheckedModeBanner: false,
      themeMode: AppTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: KeyedSubtree(
        key: ValueKey(_themeMode),
        child: const CaptureHomeScreen(),
      ),
    );

    if (widget.viewModel != null) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<TSharkCaptureViewModel>.value(
            value: widget.viewModel!,
          ),
        ],
        child: app,
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TSharkCaptureViewModel>(
          create: (_) => TSharkCaptureViewModel(
            initialAdapterConfig: widget.launchAdapterConfig,
          ),
        ),
      ],
      child: app,
    );
  }
}
