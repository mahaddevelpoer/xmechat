import 'package:flutter/widgets.dart';

/// Global navigator key so services (notifications/background listeners)
/// can navigate without having a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

