import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ApkShareService {
  ApkShareService._();

  static final ApkShareService instance = ApkShareService._();

  static const MethodChannel _channel = MethodChannel('fast_n_fresh/app');

  Future<void> shareCurrentApk() async {
    final apkPath = await _channel.invokeMethod<String>('getApkPath');
    if (apkPath == null || apkPath.trim().isEmpty) {
      throw StateError('Could not locate the installed APK.');
    }

    await Share.shareXFiles(
      [
        XFile(
          apkPath,
          mimeType: 'application/vnd.android.package-archive',
          name: 'fast-n-fresh.apk',
        ),
      ],
      subject: 'PWP POS APK',
      text: 'PWP POS Cafe Management App',
    );
  }
}
