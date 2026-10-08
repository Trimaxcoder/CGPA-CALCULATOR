// ══════════════════════════════════════════════════════════
//  COMBO FIELD
//  Text field with a suggestion list.
//  NOTE: `dark: true`  = dark text on a LIGHT background (white panel)
//        `dark: false` = light text on a DARK/gradient background
//  Desktop: arrow keys move through the list, Enter selects, Esc closes,
//  and the row under the mouse is highlighted.
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ComboField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> suggestions;
  final bool dark;
  final String? Function(String?)? validator;
  final void Function(String)? onSuggestionSelected;

  const ComboField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.suggestions,
    this.dark = false,
    this.validator,
    this.onSuggestionSelected,
  });

  @override
  State<ComboField> createState() => ComboFieldState();
}

class ComboFieldState extends State<ComboField> {
  late final FocusNode _focusNode;
  bool _showList = false;
  List<String> _filtered = [];
  int _highlight = -1; // keyboard / hover highlighted row
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _onKey);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _filtered = _buildFiltered(widget.controller.text);
          _showList = _filtered.isNotEmpty;
          _highlight = -1;
        });
      } else {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showList = false);
        });
      }
    });
  }

  @override
  void didUpdateWidget(ComboField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      _filtered = _buildFiltered(widget.controller.text);
      _highlight = -1;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<String> _buildFiltered(String q) {
    if (q.trim().isEmpty) return widget.suggestions;
    return widget.suggestions
        .where((s) => s.toLowerCase().contains(q.trim().toLowerCase()))
        .toList();
  }

  void _pick(String val) {
    widget.controller.text = val;
    _focusNode.unfocus();
    setState(() {
      _showList = false;
      _highlight = -1;
    });
    widget.onSuggestionSelected?.call(val);
  }

  // ── Keyboard support ───────────────────────────────────────
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (_filtered.isEmpty) return KeyEventResult.ignored;
      setState(() {
        _showList = true;
        final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _highlight = (_highlight + delta).clamp(0, _filtered.length - 1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _itemKeys[_highlight]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 90),
          );
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter && _showList && _highlight >= 0) {
      if (_highlight < _filtered.length) {
        _pick(_filtered[_highlight]);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.escape && _showList) {
      setState(() {
        _showList = false;
        _highlight = -1;
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.dark;
    final textColor = isDark ? Colors.black87 : Colors.white;
    final fillColor = isDark
        ? Colors.grey.shade50
        : Colors.white.withOpacity(0.08);
    final labelColor = isDark ? Colors.black54 : Colors.white70;
    final borderColor = isDark ? Colors.grey.shade300 : Colors.white24;
    final focusColor = isDark ? Colors.blue : Colors.blue.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: TextStyle(color: textColor, fontSize: 14),
          validator: widget.validator,
          onChanged: (v) {
            setState(() {
              _filtered = _buildFiltered(v);
              _showList = _filtered.isNotEmpty;
              _highlight = -1;
            });
          },
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Type or select from list',
            hintStyle: TextStyle(
              color: isDark ? Colors.black26 : Colors.white30,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              widget.icon,
              color: isDark ? Colors.blue : Colors.blue.shade300,
            ),
            suffixIcon: widget.suggestions.isNotEmpty
                ? Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.black38 : Colors.white38,
                  )
                : null,
            filled: true,
            fillColor: fillColor,
            labelStyle: TextStyle(color: labelColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: focusColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
        ),
        if (_showList)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.indigo.shade900,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: Colors.black12) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final item = _filtered[i];
                  final highlighted = i == _highlight;
                  return InkWell(
                    key: _itemKeys.putIfAbsent(i, () => GlobalKey()),
                    onTap: () => _pick(item),
                    onHover: (h) {
                      if (h && _highlight != i) setState(() => _highlight = i);
                    },
                    child: Container(
                      color: highlighted
                          ? (isDark
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.white.withOpacity(0.14))
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: isDark ? Colors.black87 : Colors.white,
                          fontSize: 13,
                          fontWeight: highlighted
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}