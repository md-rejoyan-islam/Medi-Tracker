import 'package:flutter/material.dart';

/// Custom bottom navigation bar tuned for a "premium" feel.
///
/// Differences vs. the stock Material 3 [NavigationBar]:
/// - **Floating effect**: subtle shadow above the bar separates it from the
///   content scroll without a hard divider line.
/// - **Morphing pill indicator**: the selected item's background pill
///   expands and tints in brand colour with a 250 ms ease curve, instead
///   of the static wide pill that the default uses.
/// - **Two-tier typography**: active label bumps to weight-700 in the
///   `onSurface` colour; inactive stays weight-500 in `onSurfaceVariant`.
/// - **Compact height** (64 dp + safe-area) for more screen real estate
///   without losing touch-target comfort.
class PremiumNavBar extends StatelessWidget {
  const PremiumNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<PremiumNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumNavDestination {
  const PremiumNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final PremiumNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 260);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final pillColor = selected
        ? scheme.primaryContainer
        : Colors.transparent;
    final iconColor = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated pill that grows + tints when selected.
            AnimatedContainer(
              duration: _duration,
              curve: _curve,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedSwitcher(
                duration: _duration,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  key: ValueKey('${destination.label}-$selected'),
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: _duration,
              curve: _curve,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
                color: labelColor,
              ),
              child: Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
