import 'package:flutter/material.dart';

class ChordVisibilityToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ChordVisibilityToggle(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: value ? 'Hide chords' : 'Show chords',
        child: MergeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.music_note_rounded : Icons.music_off_rounded,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          const Text('Chords'),
          const SizedBox(width: 6),
          Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ])),
      );
}
