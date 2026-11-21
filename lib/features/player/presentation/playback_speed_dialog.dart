import 'package:flutter/material.dart';

class PlaybackSpeedDialog extends StatefulWidget {
  const PlaybackSpeedDialog({
    super.key,
    required this.initialSpeed,
    required this.onChanged,
    required this.onError,
  });

  static const minSpeed = 0.5;
  static const maxSpeed = 2.0;

  final double initialSpeed;
  final Future<void> Function(double speed) onChanged;
  final ValueChanged<Object> onError;

  @override
  State<PlaybackSpeedDialog> createState() => _PlaybackSpeedDialogState();
}

class _PlaybackSpeedDialogState extends State<PlaybackSpeedDialog> {
  late double _speed = widget.initialSpeed;
  late double _appliedSpeed = widget.initialSpeed;

  Future<void> _applySpeed(double speed) async {
    try {
      await widget.onChanged(speed);
      _appliedSpeed = speed;
    } catch (error) {
      if (mounted) setState(() => _speed = _appliedSpeed);
      widget.onError(error);
    }
  }

  String _formatSpeed(double speed) =>
      '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}×';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Kecepatan pemutaran'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatSpeed(_speed),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Slider(
          min: PlaybackSpeedDialog.minSpeed,
          max: PlaybackSpeedDialog.maxSpeed,
          divisions: 6,
          value: _speed,
          label: _formatSpeed(_speed),
          onChanged: (value) => setState(() => _speed = value),
          onChangeEnd: _applySpeed,
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('0.5×'), Text('2×')],
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Selesai'),
      ),
    ],
  );
}
