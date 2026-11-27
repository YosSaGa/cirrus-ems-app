import 'package:http/http.dart' as http;

import 'api_client_factory_stub.dart'
    if (dart.library.html) 'api_client_factory_web.dart'
    as platform;

http.Client createApiClient() => platform.createApiClient();
