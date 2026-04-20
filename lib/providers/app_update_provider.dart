import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_update_service.dart';

final appUpdateStatusProvider = FutureProvider<AppUpdateStatus>((ref) async {
  return AppUpdateService.checkStatus();
});

final storeUpdateStatusProvider = FutureProvider<StoreUpdateStatus>((
  ref,
) async {
  return AppUpdateService.checkStoreUpdateStatus();
});
