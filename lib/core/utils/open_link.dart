import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';

/// Opens [url] in an external app and reports failures with a snackbar.
Future<void> openExternalLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Exception {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text(AppStrings.linkOpenError)),
    );
  }
}
