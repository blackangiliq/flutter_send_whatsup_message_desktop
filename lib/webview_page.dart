
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class WhatsAppWebView extends StatelessWidget {
  final WebviewController webController;

  WhatsAppWebView({required this.webController});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1000,
      color: Colors.transparent,
      child: Webview(
        webController,
        permissionRequested: (url, kind, isUserInitiated) =>
        WebviewPermissionDecision.allow,
      ),
    );
  }
}
