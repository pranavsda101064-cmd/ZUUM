import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Themed bottom-sheet scaffold: drag handle, optional title, child content.
abstract final class ZSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    bool showClose = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpacing.xxl,
                0,
                ZSpacing.xxl,
                ZSpacing.xxl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null || showClose)
                    Padding(
                      padding: const EdgeInsets.only(top: ZSpacing.sm),
                      child: Row(
                        children: [
                          if (title != null)
                            Expanded(
                              child: Text(title, style: ZTypography.titleMd),
                            ),
                          if (showClose)
                            IconButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              color: ZColors.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadii.xl)),
      ),
    );
  }
}
