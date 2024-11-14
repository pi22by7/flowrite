// lib/widgets/new_file_dialog.dart
import 'package:flutter/material.dart';

class NewFileDialog extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  NewFileDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New File'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'File Name',
          hintText: 'Enter file name',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, name);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
