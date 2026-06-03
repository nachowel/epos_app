import 'package:flutter/material.dart';

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.title,
    required this.message,
    this.databasePath,
    this.backupDirectoryPath,
    this.technicalDetails,
  });

  const StartupFailureApp.databaseMigrationFailure({
    super.key,
    required String this.databasePath,
    required String this.backupDirectoryPath,
    this.technicalDetails,
  }) : title = 'Database update failed',
       message =
           'The local database could not be upgraded safely. The app has stopped before opening the till. The database was not modified by the installer; restore from backup if needed.';

  final String title;
  final String message;
  final String? databasePath;
  final String? backupDirectoryPath;
  final String? technicalDetails;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F7F4),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Text(message, style: Theme.of(context).textTheme.bodyLarge),
                    if (databasePath != null) ...<Widget>[
                      const SizedBox(height: 24),
                      _FailureDetail(label: 'Database', value: databasePath!),
                    ],
                    if (backupDirectoryPath != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _FailureDetail(
                        label: 'Backup folder',
                        value: backupDirectoryPath!,
                      ),
                    ],
                    if (technicalDetails != null &&
                        technicalDetails!.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 24),
                      Text(
                        'Technical detail',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        technicalDetails!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureDetail extends StatelessWidget {
  const _FailureDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
