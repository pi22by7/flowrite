// lib/screens/editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/writing_file.dart';
import '../services/syllable_service.dart';

class EditorScreen extends StatefulWidget {
  final WritingFile file;

  const EditorScreen({super.key, required this.file});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final SyllableService _syllableService = SyllableService();

  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  List<FocusNode> _keyboardFocusNodes = [];
  List<int> _syllableCounts = [];
  int _currentLine = 0;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final content = await widget.file.readContent();
    final lines = content.split('\n');

    _controllers = [];
    _focusNodes = [];
    _keyboardFocusNodes = [];
    _syllableCounts = [];

    for (int i = 0; i < lines.length; i++) {
      final index = i; // Capture index
      final controller = TextEditingController(text: lines[i]);
      final focusNode = FocusNode();
      final keyboardFocusNode = FocusNode();

      controller.addListener(() => _onLineChanged(index));
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          setState(() {
            _currentLine = index;
          });
        }
      });

      _controllers.add(controller);
      _focusNodes.add(focusNode);
      _keyboardFocusNodes.add(keyboardFocusNode);
      _syllableCounts.add(_syllableService.countSyllables(lines[i]));
    }

    setState(() {});
  }

  void _onLineChanged(int index) {
    final text = _controllers[index].text;
    final syllableCount = _syllableService.countSyllables(text);

    setState(() {
      _syllableCounts[index] = syllableCount;
    });
  }

  void _addNewLine() {
    final index = _controllers.length; // Capture current index before adding
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final keyboardFocusNode = FocusNode();

    controller.addListener(() => _onLineChanged(index));
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        setState(() {
          _currentLine = index;
        });
      }
    });

    setState(() {
      _controllers.add(controller);
      _focusNodes.add(focusNode);
      _keyboardFocusNodes.add(keyboardFocusNode);
      _syllableCounts.add(0);
    });

    // Auto-focus the new line
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(focusNode);
    });
  }


  Future<void> _saveContent() async {
    final lines = _controllers.map((c) => c.text).toList();
    final content = lines.join('\n');
    await widget.file.writeContent(content);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Saved successfully')),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    for (var focusNode in _keyboardFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _handleEnterKey(int index) {
    if (index + 1 < _controllers.length) {
      // Move focus to the next existing line
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else {
      // Add a new line and focus on it if at the end
      _addNewLine();
    }
  }

  void _handleBackspaceKey(int index) {
    if (_controllers.length > 1 && _controllers[index].text.isEmpty) {
      final controller = _controllers.removeAt(index);
      final focusNode = _focusNodes.removeAt(index);
      final keyboardFocusNode = _keyboardFocusNodes.removeAt(index); // Add this line
      _syllableCounts.removeAt(index);

      controller.dispose();
      focusNode.dispose();
      keyboardFocusNode.dispose(); // Add this line

      if (index > 0) {
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveContent,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: _controllers.length,
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: _keyboardFocusNodes[index],
                  onKeyEvent: (KeyEvent event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace &&
                        _controllers[index].text.isEmpty) {
                      _handleBackspaceKey(index);
                    }
                  },
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    maxLines: null,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    onChanged: (value) => _onLineChanged(index),
                    onEditingComplete: () => _handleEnterKey(index),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')), // Prevent newlines
                    ],
                  ),
                ),
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.dividerColor,
                    ),
                  ),
                  color: index == _currentLine ? theme.colorScheme.primary.withOpacity(0.1) : null,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (index == _currentLine)
                      Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                    Text(
                      '${_syllableCounts[index]}',
                      style: TextStyle(
                        color: index == _currentLine
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: index == _currentLine
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

