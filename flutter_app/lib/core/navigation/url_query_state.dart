import 'url_query_state_stub.dart'
    if (dart.library.html) 'url_query_state_web.dart' as impl;

String? currentPostIdFromUrl() => impl.currentPostIdFromUrl();

void setPostIdOnUrl(String? postId) => impl.setPostIdOnUrl(postId);

String? takeQueryParameterFromUrl(String key) => impl.takeQueryParameterFromUrl(key);
