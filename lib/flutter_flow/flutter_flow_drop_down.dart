import 'package:flutter/material.dart';

import 'form_field_controller.dart';

// Single-select dropdown. `isSearchable` and `isMultiSelect` are accepted so
// FlutterFlow-generated pages compile, but are not implemented yet.
class FlutterFlowDropDown<T> extends StatefulWidget {
  const FlutterFlowDropDown({
    super.key,
    this.controller,
    this.multiSelectController,
    this.hintText,
    this.searchHintText,
    required this.options,
    this.optionLabels,
    this.onChanged,
    this.onMultiSelectChanged,
    this.icon,
    this.width,
    this.height,
    this.maxHeight,
    this.fillColor,
    this.searchHintTextStyle,
    this.searchTextStyle,
    this.searchCursorColor,
    required this.textStyle,
    required this.elevation,
    required this.borderWidth,
    required this.borderRadius,
    required this.borderColor,
    required this.margin,
    this.hidesUnderline = false,
    this.disabled = false,
    this.isOverButton = false,
    this.menuOffset,
    this.isSearchable = false,
    this.isMultiSelect = false,
    this.labelText,
    this.labelTextStyle,
  });

  final FormFieldController<T?>? controller;
  final FormFieldController<List<T>?>? multiSelectController;
  final String? hintText;
  final String? searchHintText;
  final List<T> options;
  final List<String>? optionLabels;
  final Function(T?)? onChanged;
  final Function(List<T>?)? onMultiSelectChanged;
  final Widget? icon;
  final double? width;
  final double? height;
  final double? maxHeight;
  final Color? fillColor;
  final TextStyle? searchHintTextStyle;
  final TextStyle? searchTextStyle;
  final Color? searchCursorColor;
  final TextStyle textStyle;
  final double elevation;
  final double borderWidth;
  final double borderRadius;
  final Color borderColor;
  final EdgeInsetsGeometry margin;
  final bool hidesUnderline;
  final bool disabled;
  final bool isOverButton;
  final Offset? menuOffset;
  final bool isSearchable;
  final bool isMultiSelect;
  final String? labelText;
  final TextStyle? labelTextStyle;

  @override
  State<FlutterFlowDropDown<T>> createState() => _FlutterFlowDropDownState<T>();
}

class _FlutterFlowDropDownState<T> extends State<FlutterFlowDropDown<T>> {
  T? get currentValue {
    final value = widget.controller?.value;
    return widget.options.contains(value) ? value : null;
  }

  Map<T, String> get optionLabels => Map.fromEntries(
    widget.options.asMap().entries.map(
      (option) => MapEntry(
        option.value,
        widget.optionLabels == null ||
                widget.optionLabels!.length < option.key + 1
            ? option.value.toString()
            : widget.optionLabels![option.key],
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(FlutterFlowDropDown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    widget.onChanged?.call(widget.controller?.value);
  }

  void _onSelected(T? value) {
    if (widget.controller != null) {
      // The controller listener forwards the change to `onChanged`.
      widget.controller!.value = value;
    } else {
      widget.onChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = optionLabels;

    final dropdown = DropdownButton<T>(
      value: currentValue,
      hint: widget.hintText != null
          ? Text(widget.hintText!, style: widget.textStyle)
          : null,
      items: widget.options
          .map(
            (option) => DropdownMenuItem<T>(
              value: option,
              child: Text(labels[option] ?? '', style: widget.textStyle),
            ),
          )
          .toList(),
      onChanged: widget.disabled ? null : _onSelected,
      icon: widget.icon,
      isExpanded: true,
      isDense: true,
      elevation: widget.elevation.toInt(),
      dropdownColor: widget.fillColor,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      menuMaxHeight: widget.maxHeight,
      focusColor: Colors.transparent,
      style: widget.textStyle,
      underline: widget.hidesUnderline ? const SizedBox.shrink() : null,
    );

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.borderColor,
          width: widget.borderWidth,
        ),
        color: widget.fillColor,
      ),
      child: Padding(
        padding: widget.margin,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: widget.labelText == null || widget.labelText!.isEmpty
              ? dropdown
              : InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.labelText,
                    labelStyle: widget.labelTextStyle,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  child: dropdown,
                ),
        ),
      ),
    );
  }
}
