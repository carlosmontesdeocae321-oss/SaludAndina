import 'package:flutter/widgets.dart';
import 'route_observer.dart';

mixin RouteRefreshMixin<T extends StatefulWidget> on State<T>
    implements RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal != null) routeObserver.subscribe(this, modal);
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when coming back to this route (another route was popped)
    onRouteRefreshed();
  }

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  /// Implement this in the State to refresh data (e.g. call _load())
  void onRouteRefreshed();
}
