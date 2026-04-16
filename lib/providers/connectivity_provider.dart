import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 네트워크 연결 상태 스트림
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // 초기 상태 즉시 방출
  final initial = await connectivity.checkConnectivity();
  yield !initial.contains(ConnectivityResult.none);

  // 이후 변경 사항 스트리밍
  await for (final results in connectivity.onConnectivityChanged) {
    yield !results.contains(ConnectivityResult.none);
  }
});

/// bool 형태로 현재 온라인 여부만 제공 (편의 Provider)
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? true;
});
