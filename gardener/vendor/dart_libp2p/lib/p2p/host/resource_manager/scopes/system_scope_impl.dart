import 'package:dart_libp2p/p2p/host/resource_manager/scope_impl.dart';

/// SystemScopeImpl is the concrete implementation for the system-wide scope.
/// It doesn't add specific new behavior beyond the base ResourceScopeImpl
/// but ensures it implements the `ResourceScope` interface (which ResourceScopeImpl already does).
class SystemScopeImpl extends ResourceScopeImpl {
  SystemScopeImpl(super.limit, super.name, {super.edges});

  // No additional methods needed as ResourceScopeImpl already fulfills ResourceScope.
  // This class primarily serves for type clarity and potential future extensions specific to SystemScope.
}
