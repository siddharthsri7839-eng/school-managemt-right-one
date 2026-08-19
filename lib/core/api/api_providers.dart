import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

// This is now the single, central provider for our ApiClient.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());