import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; // Import ajouté
import 'dart:io';
import 'package:image/image.dart' as img;

class LogoManager {
  static const String defaultLogoPath = 'assets/images/logo.png';

  /// Charge et traite le logo
  static Future<File> processLogo({int borderSize = 10}) async {
    try {
      // 1. Charger l'image depuis les assets
      final byteData = await rootBundle.load(defaultLogoPath);
      
      // 2. Décoder l'image
      final image = img.decodeImage(byteData.buffer.asUint8List());
      if (image == null) throw Exception('Échec du décodage de l\'image');
      
      // 3. Recadrer l'image
      final trimmed = img.copyCrop(
        image,
        x: borderSize,
        y: borderSize,
        width: image.width - (borderSize * 2),
        height: image.height - (borderSize * 2),
      );

      // 4. Sauvegarder dans le répertoire de l'application
      final directory = await getApplicationDocumentsDirectory();
      final outputFile = File('${directory.path}/logo_trimmed.png');
      await outputFile.writeAsBytes(img.encodePng(trimmed));
      
      return outputFile;
    } catch (e) {
      debugPrint('Erreur de traitement du logo: $e');
      rethrow;
    }
  }

  /// Widget réutilisable pour afficher le logo
  static Widget buildLogo({
    double width = 150,
    double height = 150,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    return FutureBuilder<File>(
      future: processLogo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return _buildErrorWidget();
          }
          return Image.file(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            color: color,
          );
        }
        return const CircularProgressIndicator();
      },
    );
  }

  static Widget _buildErrorWidget() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 50),
        SizedBox(height: 10),
        Text('Erreur de chargement du logo', style: TextStyle(color: Colors.red)),
      ],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion de Logo Professionnelle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LogoDemoPage(),
    );
  }
}

class LogoDemoPage extends StatelessWidget {
  const LogoDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logo Professionnel'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LogoManager.buildLogo(width: 200, height: 200),
            const SizedBox(height: 30),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await LogoManager.processLogo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logo traité avec succès')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Rafraîchir le Logo'),
            ),
          ],
        ),
      ),
    );
  }
}