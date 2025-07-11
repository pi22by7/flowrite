import 'package:flutter/material.dart';

class FileDialog extends StatefulWidget {
  final String initialName;
  final String title;
  final bool isRename;

  const FileDialog({
    super.key,
    required this.initialName,
    required this.title,
    this.isRename = false,
  });

  @override
  State<FileDialog> createState() => _FileDialogState();
}

class _FileDialogState extends State<FileDialog> {
  late final TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _isValid = widget.initialName.isNotEmpty;
    _controller.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isValid = _controller.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        widget.title.isNotEmpty ? widget.title : 'Create New Note',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Note Name',
              hintText: 'Enter note name',
              prefixIcon: Icon(
                widget.isRename ? Icons.edit_outlined : Icons.note_add_outlined,
                color: colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: colorScheme.primary.withAlpha(12),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: _isValid ? (_) => _submitName() : null,
          ),
          if (!_isValid) ...[
            const SizedBox(height: 8),
            Text(
              'Please enter a name',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: colorScheme.onSurface.withAlpha(178)),
          ),
        ),
        FilledButton(
          onPressed: _isValid ? _submitName : null,
          child: Text(widget.isRename ? 'Rename' : 'Create'),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
    );
  }

  void _submitName() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }
}
