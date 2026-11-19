import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'screens/home_screen.dart';
import 'screens/permissions_screen.dart';
import 'services/permissions_service.dart';
import 'services/qshare_storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QShareApp());
}

/// Resolve the receive folder once at startup and share it with the
/// screens through a simple inherited holder.
class QShareDir {
  QShareDir(this.dir, this.isPublicFolder);

  final Directory dir;
  final bool isPublicFolder;
}

Future<QShareDir> resolveQShareDir() async {
  final hasAccess = await PermissionsService.hasAllFilesAccess();
  Directory? appExt;
  try {
    appExt = await getExternalStorageDirectory();
  } catch (_) {
    appExt = null;
  }
  final dir = QShareStorage.resolve(
    hasAllFilesAccess: hasAccess,
    appExternalDir: appExt,
  );
  QShareStorage.ensureWritable(dir);
  return QShareDir(dir, hasAccess);
}

class QShareApp extends StatelessWidget {
  const QShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QShare — كيو شير',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: qshareTheme(),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  late Future<bool> _askedFuture;
  QShareDir? _dir;

  @override
  void initState() {
    super.initState();
    _askedFuture = PermissionsService.wasAsked();
    _loadDir();
  }

  Future<void> _loadDir() async {
    final dir = await resolveQShareDir();
    if (mounted) setState(() => _dir = dir);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _askedFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.data!) {
          return PermissionsScreen(
            onDone: () async {
              await _loadDir();
              if (mounted) {
                setState(() => _askedFuture = Future.value(true));
              }
            },
          );
        }
        final dir = _dir;
        if (dir == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(qshareDir: dir);
      },
    );
  }
}
