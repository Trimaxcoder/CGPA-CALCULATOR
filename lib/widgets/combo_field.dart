// ══════════════════════════════════════════════════════════
//  COMBO FIELD  (unchanged)
// ══════════════════════════════════════════════════════════


import 'package:flutter/material.dart';

class ComboField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> suggestions;
  final bool dark;
  final String? Function(String?)? validator;
  final void Function(String)? onSuggestionSelected;

  const ComboField({
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
  final _focusNode = FocusNode();
  bool _showList = false;
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _filtered = _buildFiltered(widget.controller.text);
          _showList = _filtered.isNotEmpty;
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
    setState(() => _showList = false);
    widget.onSuggestionSelected?.call(val);
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
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.indigo.shade900,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                return InkWell(
                  onTap: () => _pick(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: isDark ? Colors.black87 : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}