import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  // Tu URL real configurada
  static const String versionJsonUrl = 'https://macgalaviz.github.io/isan/version.json';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Obtener versión instalada en el celular
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Intentar leer el JSON de internet
      // El timeout es importante: si en 3 segundos no responde (internet lento), cancela para no molestar.
      final response = await http.get(Uri.parse(versionJsonUrl)).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Leemos TUS campos específicos del JSON
        String latestVersion = data['version'];
        String changelog = data['changelog'] ?? "Mejoras generales";
        
        // Lógica Multi-Plataforma 💻📱
        String downloadUrl = "";
        
        if (Platform.isAndroid) {
          downloadUrl = data['download_url_android'] ?? "";
        } else if (Platform.isWindows) {
          downloadUrl = data['download_url_windows'] ?? "";
        }

        // 3. Comparación Inteligente
        // Solo avisamos si la versión es distinta Y si hay un link de descarga configurado
        if (latestVersion != currentVersion && downloadUrl.isNotEmpty) {
          _showUpdateDialog(context, latestVersion, downloadUrl, changelog);
        }
      }
    } catch (e) {
      // 4. "Si no hay internet, trabajar con la app tal como está"
      // Si entra aquí es porque falló el internet o el servidor.
      // No hacemos NADA (print solo para que tú lo veas en consola al programar).
      print("No se pudo verificar actualización (Sin internet o timeout): $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String url, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("¡Nueva versión disponible! ($newVersion)"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Cambios:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(notes), // Aquí mostramos tu 'changelog'
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Más tarde"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text("ACTUALIZAR"),
              onPressed: () {
                _launchURL(url);
                Navigator.of(context).pop(); // Cierra la alerta después de dar click
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print("No se pudo abrir el link: $url");
    }
  }
}
