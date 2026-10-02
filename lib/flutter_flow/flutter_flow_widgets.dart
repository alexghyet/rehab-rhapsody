import 'package:flutter/material.dart';

class FFButtonOptions {
  const FFButtonOptions({
    this.textAlign,
    this.textStyle,
    this.elevation,
    this.height,
    this.width,
    this.padding,
    this.color,
    this.disabledColor,
    this.disabledTextColor,
    this.splashColor,
    this.iconSize,
    this.iconColor,
    this.iconAlignment,
    this.iconPadding,
    this.borderRadius,
    this.borderSide,
    this.hoverColor,
    this.hoverBorderSide,
    this.hoverTextColor,
    this.hoverElevation,
    this.maxLines,
  });

  final TextAlign? textAlign;
  final TextStyle? textStyle;
  final double? elevation;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? disabledColor;
  final Color? disabledTextColor;
  final int? maxLines;
  final Color? splashColor;
  final double? iconSize;
  final Color? iconColor;
  final IconAlignment? iconAlignment;
  final EdgeInsetsGeometry? iconPadding;
  final BorderRadius? borderRadius;
  final BorderSide? borderSide;
  final Color? hoverColor;
  final BorderSide? hoverBorderSide;
  final Color? hoverTextColor;
  final double? hoverElevation;
}

class FFButtonWidget extends StatefulWidget {
  const FFButtonWidget({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.iconData,
    required this.options,
    this.showLoadingIndicator = true,
  });

  final String text;
  final Widget? icon;
  final IconData? iconData;
  final Function()? onPressed;
  final FFButtonOptions options;
  final bool showLoadingIndicator;

  @override
  State<FFButtonWidget> createState() => _FFButtonWidgetState();
}

class _FFButtonWidgetState extends State<FFButtonWidget> {
  bool loading = false;

  int get maxLines => widget.options.maxLines ?? 1;

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    final textStyle = options.textStyle;

    Widget textWidget = loading
        ? SizedBox(
            width: 23,
            height: 23,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                textStyle?.color ?? Colors.white,
              ),
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.text,
              style: textStyle?.merge(const TextStyle(decoration: null)),
              textAlign: options.textAlign,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          );

    final onPressed = widget.onPressed != null
        ? (widget.showLoadingIndicator
              ? () async {
                  if (loading) {
                    return;
                  }
                  setState(() => loading = true);
                  try {
                    await widget.onPressed!();
                  } finally {
                    if (mounted) {
                      setState(() => loading = false);
                    }
                  }
                }
              : () => widget.onPressed!())
        : null;

    final style = ButtonStyle(
      shape: WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
        if (states.contains(WidgetState.hovered) &&
            options.hoverBorderSide != null) {
          return RoundedRectangleBorder(
            borderRadius: options.borderRadius ?? BorderRadius.circular(8),
            side: options.hoverBorderSide!,
          );
        }
        return RoundedRectangleBorder(
          borderRadius: options.borderRadius ?? BorderRadius.circular(8),
          side: options.borderSide ?? BorderSide.none,
        );
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled) &&
            options.disabledTextColor != null) {
          return options.disabledTextColor;
        }
        if (states.contains(WidgetState.hovered) &&
            options.hoverTextColor != null) {
          return options.hoverTextColor;
        }
        return textStyle?.color ?? Colors.white;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled) &&
            options.disabledColor != null) {
          return options.disabledColor;
        }
        if (states.contains(WidgetState.hovered) &&
            options.hoverColor != null) {
          return options.hoverColor;
        }
        return options.color;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return options.splashColor;
        }
        return options.hoverColor == null ? null : Colors.transparent;
      }),
      padding: WidgetStateProperty.all(
        options.padding ??
            const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      ),
      elevation: WidgetStateProperty.resolveWith<double?>((states) {
        if (states.contains(WidgetState.hovered) &&
            options.hoverElevation != null) {
          return options.hoverElevation!;
        }
        return options.elevation ?? 2.0;
      }),
      iconColor: WidgetStateProperty.all(options.iconColor),
    );

    final icon =
        widget.icon ??
        (widget.iconData != null
            ? Icon(
                widget.iconData,
                size: options.iconSize,
                color: options.iconColor,
              )
            : null);

    if (icon != null && !loading) {
      return SizedBox(
        height: options.height,
        width: options.width,
        child: ElevatedButton.icon(
          icon: Padding(
            padding: options.iconPadding ?? EdgeInsets.zero,
            child: icon,
          ),
          label: textWidget,
          onPressed: onPressed,
          style: style,
          iconAlignment: options.iconAlignment ?? IconAlignment.start,
        ),
      );
    }

    return SizedBox(
      height: options.height,
      width: options.width,
      child: ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: textWidget,
      ),
    );
  }
}
