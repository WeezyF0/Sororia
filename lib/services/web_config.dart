import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebConfig {
  static bool get isWeb => kIsWeb;
  
  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;
  
  // Get device type based on width
  static DeviceType getDeviceType(double width) {
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }
  
  // Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (!isWeb) return const EdgeInsets.all(16.0);
    
    switch (getDeviceType(width)) {
      case DeviceType.mobile:
        return const EdgeInsets.all(16.0);
      case DeviceType.tablet:
        return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0);
      case DeviceType.desktop:
        return const EdgeInsets.symmetric(horizontal: 64.0, vertical: 24.0);
    }
  }
  
  // Get responsive max width for content
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (!isWeb) return width;
    
    switch (getDeviceType(width)) {
      case DeviceType.mobile:
        return width;
      case DeviceType.tablet:
        return 768;
      case DeviceType.desktop:
        return 1200;
    }
  }
  
  // Get responsive column count for grids
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (!isWeb) return 2;
    
    switch (getDeviceType(width)) {
      case DeviceType.mobile:
        return 1;
      case DeviceType.tablet:
        return 2;
      case DeviceType.desktop:
        return 3;
    }
  }
  
  // Check if side navigation should be used
  static bool useSideNavigation(BuildContext context) {
    if (!isWeb) return false;
    return getDeviceType(MediaQuery.of(context).size.width) == DeviceType.desktop;
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}

// Web-specific app bar for desktop
class WebAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  
  const WebAppBar({
    Key? key,
    required this.title,
    this.actions,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!WebConfig.isWeb || !WebConfig.useSideNavigation(context)) {
      return AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      );
    }
    
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64.0);
}

// Responsive container for centering content on web
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  
  const ResponsiveContainer({
    Key? key,
    required this.child,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? WebConfig.getResponsivePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: WebConfig.getMaxContentWidth(context),
          ),
          child: child,
        ),
      ),
    );
  }
}
