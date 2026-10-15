import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(width: 1024, height: 0)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let performanceChannel = FlutterMethodChannel(
      name: "peak_bagger/performance", binaryMessenger: flutterViewController.engine.binaryMessenger)
    performanceChannel.setMethodCallHandler { call, result in
      guard call.method == "clock" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let env = ProcessInfo.processInfo.environment
      var clock: [String: Any] = [
        "native_now_us": performanceMonotonicMicroseconds(),
        "native_entry_us": AppDelegate.nativeEntryUs,
        "run_id": env["PEAK_BAGGER_MEASUREMENT_RUN"] ?? "unlabelled",
        "condition": env["PEAK_BAGGER_MEASUREMENT_CONDITION"] ?? "unspecified",
        "repetition": env["PEAK_BAGGER_MEASUREMENT_REPETITION"] ?? "unspecified"
      ]
      clock["launch_method"] = env["PEAK_BAGGER_MEASUREMENT_LAUNCH_METHOD"] ?? "pre-exec direct built binary"
      clock.merge(performanceProcessLaunchClock()) { _, new in new }
      if let value = env["PEAK_BAGGER_LAUNCH_BEFORE_EXEC_US"], let launch = UInt64(value) {
        clock["launch_before_exec_us"] = launch
      }
      result(clock)
    }

    // Start in maximized mode
    self.zoom(nil)

    super.awakeFromNib()
  }
}
