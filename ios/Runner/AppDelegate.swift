import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // WorkManager: 백그라운드 Dart isolate에서 플러그인 사용 가능하도록 등록
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // BGTaskScheduler에 태스크 식별자 등록 (Info.plist의 identifier와 일치해야 함)
    WorkmanagerPlugin.registerTask(withIdentifier: "com.imchic.pinstock.PinStock_news_check")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
