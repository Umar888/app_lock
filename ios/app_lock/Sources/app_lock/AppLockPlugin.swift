import Flutter
import UIKit

/// Hides app content in the app switcher by covering the window with a blur
/// while the app is inactive.
public class AppLockPlugin: NSObject, FlutterPlugin {
  private var mode = "none"
  // the biometric prompt makes the app inactive too; don't cover the lock
  // screen behind Face ID
  private var suspended = false
  private var cover: UIView?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app_lock/privacy", binaryMessenger: registrar.messenger())
    let instance = AppLockPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.observeLifecycle()
  }

  private func observeLifecycle() {
    let center = NotificationCenter.default
    // scene notifications for UIScene apps, app ones for the rest; showCover
    // and hideCover are idempotent so getting both is fine
    center.addObserver(self, selector: #selector(willResignActive), name: UIScene.willDeactivateNotification, object: nil)
    center.addObserver(self, selector: #selector(didBecomeActive), name: UIScene.didActivateNotification, object: nil)
    center.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "setMode":
      mode = args?["mode"] as? String ?? "none"
      if mode == "none" { hideCover(animated: false) }
      result(nil)
    case "setSuspended":
      suspended = args?["suspended"] as? Bool ?? false
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func willResignActive() {
    guard mode != "none", !suspended else { return }
    showCover()
  }

  @objc private func didBecomeActive() {
    // a short delay gives Flutter time to draw the lock screen first, so the
    // content never flashes between the cover and the lock
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      self?.hideCover(animated: true)
    }
  }

  private func showCover() {
    guard cover == nil, let window = keyWindow() else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    cover = blur
  }

  private func hideCover(animated: Bool) {
    guard let view = cover else { return }
    cover = nil
    guard animated else {
      view.removeFromSuperview()
      return
    }
    UIView.animate(withDuration: 0.2, animations: { view.alpha = 0 }) { _ in
      view.removeFromSuperview()
    }
  }

  private func keyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let window = scene.windows.first(where: { $0.isKeyWindow }) { return window }
    }
    return scenes.first?.windows.first
  }
}
