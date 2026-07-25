import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static const String versionJsonUrl = 'https://macgalaviz.github.io/isan/version.json';

  static Future<void> checkForUpdates(BuildContext context) async {
    // Web updates itself on reload, and dart:io Platform doesn't exist there.
    if (kIsWeb) return;

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // Short timeout: a slow network must not stall app startup.
      final response = await http.get(Uri.parse(versionJsonUrl)).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        String latestVersion = data['version'];
        String changelog = data['changelog'] ?? "General improvements";

        String downloadUrl = "";

        if (Platform.isAndroid) {
          downloadUrl = data['download_url_android'] ?? "";
        } else if (Platform.isWindows) {
          downloadUrl = data['download_url_windows'] ?? "";
        }

        // No download link for this platform means nothing to offer.
        if (latestVersion != currentVersion && downloadUrl.isNotEmpty) {
          if (!context.mounted) return;
          _showUpdateDialog(context, latestVersion, downloadUrl, changelog);
        }
      }
    } catch (e) {
      // Offline or server down: keep working with the installed version.
      debugPrint("Update check failed (offline or timeout): $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String url, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("New version available! ($newVersion)"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Changes:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(notes),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Later"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text("UPDATE"),
              onPressed: () {
                _launchURL(url);
                Navigator.of(context).pop();
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
      debugPrint("Couldn't open link: $url");
    }
  }
}
