import 'package:flutter/material.dart';

class SleepTimerDialog extends StatelessWidget {
  const SleepTimerDialog({
    super.key,
    required this.initialRemaining,
    required this.remainingStream,
    required this.onStart,
    required this.onCancel,
  });

  static const presets = [5, 10, 15, 30, 45, 60];

  final Duration? initialRemaining;
  final Stream<Duration?> remainingStream;
  final ValueChanged<Duration> onStart;
  final VoidCallback onCancel;

  static String formatRemaining(Duration? duration) {
    if (duration == null) return '--:--';
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sleep timer'),
    content: StreamBuilder<Duration?>(
      stream: remainingStream,
      initialData: initialRemaining,
      builder: (context, snapshot) {
        final remaining = snapshot.data;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remaining != null) ...[
              Text(
                'Jeda otomatis dalam ${formatRemaining(remaining)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
            ] else
              const Text('Pilih durasi sampai pemutaran dijeda.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in presets)
                  OutlinedButton(
                    onPressed: () => onStart(Duration(minutes: minutes)),
                    child: Text('$minutes menit'),
                  ),
              ],
            ),
          ],
        );
      },
    ),
    actions: [
      StreamBuilder<Duration?>(
        stream: remainingStream,
        initialData: initialRemaining,
        builder: (context, snapshot) => snapshot.data == null
            ? const SizedBox.shrink()
            : TextButton(
                onPressed: onCancel,
                child: const Text('Batalkan timer'),
              ),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Tutup'),
      ),
    ],
  );
}
