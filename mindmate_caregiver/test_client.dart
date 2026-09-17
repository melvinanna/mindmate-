import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart';

void main() async {
  debugPrint("Initializing...");
  try {
    SupabaseClient(
      'https://ntwdneuosxsgdkzzjbvc.supabase.co',
      'foo',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    debugPrint("SupabaseClient created.");
    // We can't really call signUp without the right token, but creating it is the first step
  } catch (e) {
    debugPrint("Error: $e");
  }
}
