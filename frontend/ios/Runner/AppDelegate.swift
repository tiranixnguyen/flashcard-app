import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KeyboardLanguage") {
      KeyboardLanguage.register(messenger: registrar.messenger())
    }
  }
}

/// Tự chọn bàn phím tiếng Hàn khi focus vào ô cần gõ tiếng Hàn, và trả về bàn
/// phím đang dùng trước đó khi rời ô. Phía Dart: `keyboard_language.dart`.
///
/// Flutter không có API cho việc này trên iOS (`TextField.hintLocales` chỉ có
/// tác dụng trên Android), nên phải gắn thêm hai thuộc tính chuẩn của
/// `UIResponder` vào view nhập liệu nội bộ của engine (`FlutterTextInputView`):
/// - `textInputMode`: trả về bàn phím tiếng Hàn -> iOS tự chuyển sang nó.
/// - `textInputContextIdentifier`: iOS nhớ bàn phím dùng lần cuối theo từng
///   identifier. Ô tiếng Hàn và các ô còn lại dùng hai identifier khác nhau,
///   nên khi rời ô tiếng Hàn, iOS tự khôi phục bàn phím trước đó của ô kia —
///   đúng "chuyển lại ngôn ngữ đang dùng trước đấy".
///
/// An toàn khi engine đổi: nếu không tìm thấy class (Flutter đổi tên nội bộ),
/// mọi thứ thành no-op, app vẫn chạy bình thường, chỉ mất tính năng tự chuyển.
/// Engine hiện không tự override hai thuộc tính này (đã kiểm tra trên binary
/// Flutter 3.47.1), nên việc thêm vào không đè lên hành vi nào của Flutter.
enum KeyboardLanguage {
  /// Ngôn ngữ (BCP-47, vd "ko") mà ô đang focus mong muốn; nil = không ép.
  static var preferredLanguage: String?

  private static var installed = false

  static func register(messenger: FlutterBinaryMessenger) {
    install()
    let channel = FlutterMethodChannel(
      name: "flashcard/keyboard_language", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "prefer":
        preferredLanguage = call.arguments as? String
        reloadActiveInputView()
        result(nil)
      case "clear":
        preferredLanguage = nil
        reloadActiveInputView()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Bàn phím đang được bật trong Cài đặt khớp với ngôn ngữ mong muốn. Người
  /// dùng chưa thêm bàn phím tiếng Hàn thì trả về nil -> giữ hành vi mặc định.
  private static func matchingInputMode() -> UITextInputMode? {
    guard let lang = preferredLanguage else { return nil }
    return UITextInputMode.activeInputModes.first {
      $0.primaryLanguage?.hasPrefix(lang) ?? false
    }
  }

  private static func install() {
    guard !installed, let cls = NSClassFromString("FlutterTextInputView") else { return }
    installed = true

    addGetter(
      to: cls, selector: #selector(getter: UIResponder.textInputMode)
    ) { original in
      { obj in matchingInputMode() ?? (original(obj) as? UITextInputMode) }
    }
    addGetter(
      to: cls, selector: #selector(getter: UIResponder.textInputContextIdentifier)
    ) { original in
      { obj in
        if let lang = preferredLanguage { return "flashcard.keyboard.\(lang)" as NSString }
        return (original(obj) as? NSString) ?? ("flashcard.keyboard.default" as NSString)
      }
    }
  }

  private typealias Getter = @convention(c) (AnyObject, Selector) -> AnyObject?

  /// Thêm getter vào đúng class của engine (không đụng tới UIResponder dùng
  /// chung toàn app); `makeImpl` nhận hàm gọi bản gốc để fallback.
  private static func addGetter(
    to cls: AnyClass,
    selector: Selector,
    makeImpl: (@escaping (AnyObject) -> AnyObject?) -> (AnyObject) -> AnyObject?
  ) {
    guard let method = class_getInstanceMethod(cls, selector) else { return }
    let originalFn = unsafeBitCast(method_getImplementation(method), to: Getter.self)
    let impl = makeImpl { obj in originalFn(obj, selector) }
    let block: @convention(block) (AnyObject) -> AnyObject? = { obj in impl(obj) }
    let newImp = imp_implementationWithBlock(block)
    if !class_addMethod(cls, selector, newImp, method_getTypeEncoding(method)) {
      method_setImplementation(method, newImp)
    }
  }

  /// Ô đang mở bàn phím phải hỏi lại textInputMode thì bàn phím mới đổi ngay.
  private static func reloadActiveInputView() {
    guard let cls = NSClassFromString("FlutterTextInputView") else { return }
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows {
        if let view = firstResponder(in: window), view.isKind(of: cls) {
          view.reloadInputViews()
          return
        }
      }
    }
  }

  private static func firstResponder(in view: UIView) -> UIView? {
    if view.isFirstResponder { return view }
    for sub in view.subviews {
      if let found = firstResponder(in: sub) { return found }
    }
    return nil
  }
}
