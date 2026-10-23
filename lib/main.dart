import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/views/capture_home_screen.dart';
import 'view_models/tshark_capture_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TSharkInterfaceApp());
}

class TSharkInterfaceApp extends StatelessWidget {
  const TSharkInterfaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TSharkCaptureViewModel(),
        ),
      ],
      child: MaterialApp(
        title: 'T-Shark Interface',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const CaptureHomeScreen(),
      ),
    );
  }
}
