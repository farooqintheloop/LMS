import 'package:flutter/material.dart';
import 'theme_toggle_button.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showThemeToggle;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showThemeToggle = true,
    this.automaticallyImplyLeading = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> finalActions = <Widget>[];
    
    // Add custom actions if provided
    if (actions != null) {
      finalActions.addAll(actions!);
    }
    
    // Add theme toggle button if enabled
    if (showThemeToggle) {
      finalActions.add(const ThemeToggleButton());
    }

    return AppBar(
      title: Text(title),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: finalActions,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
