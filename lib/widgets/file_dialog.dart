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
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      title: Text(
        widget.title.isNotEmpty ? widget.title : 'Create New Note',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _controller.text.trim().isNotEmpty
                    ? colorScheme.outline.withValues(alpha: 0.4)
                    : colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Note Name',
                labelStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                hintText: 'Enter note name',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  widget.isRename
                      ? Icons.edit_outlined
                      : Icons.note_add_outlined,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: _isValid ? (_) => _submitName() : null,
            ),
          ),
          if (!_isValid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Please enter a name',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: colorScheme.error.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: _isValid
                ? colorScheme.onSurface.withValues(alpha: 0.05)
                : colorScheme.onSurface.withValues(alpha: 0.02),
            border: Border.all(
              color: _isValid
                  ? colorScheme.outline.withValues(alpha: 0.4)
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextButton(
            onPressed: _isValid ? _submitName : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              widget.isRename ? 'Rename' : 'Create',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isValid
                    ? colorScheme.onSurface.withValues(alpha: 0.9)
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _submitName() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, name);
    }
  }
}
