import Cocoa
import FlutterMacOS
import Darwin

// The launcher supplies a monotonic timestamp immediately before exec of an
// already-built app. Native entry is a distinct later milestone, not launch.
func performanceMonotonicMicroseconds() -> UInt64 {
  var timebase = mach_timebase_info_data_t()
  mach_timebase_info(&timebase)
  let ticks = mach_absolute_time()
  return (ticks / 1000) * UInt64(timebase.numer) / UInt64(timebase.denom)
}

func performanceProcessLaunchClock() -> [String: Any] {
  var info = proc_bsdinfo()
  let size = MemoryLayout<proc_bsdinfo>.stride
  guard proc_pidinfo(getpid(), PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size else {
    return ["process_launch_clock_error": "proc_pidinfo PROC_PIDTBSDINFO failed"]
  }
  let before = performanceMonotonicMicroseconds()
  var wall = timeval()
  gettimeofday(&wall, nil)
  let after = performanceMonotonicMicroseconds()
  let wallUs = Int64(wall.tv_sec) * 1_000_000 + Int64(wall.tv_usec)
  let birthWallUs = Int64(info.pbi_start_tvsec) * 1_000_000 + Int64(info.pbi_start_tvusec)
  let launchUs = birthWallUs + Int64((before + after) / 2) - wallUs
  return ["process_launch_us": launchUs,
          "process_launch_clock_uncertainty_us": (after - before + 1) / 2,
          "process_launch_clock_method": "kernel proc_bsdinfo birth timeval correlated to bracketed mach_absolute_time"]
}

@main
class AppDelegate: FlutterAppDelegate {
  static let nativeEntryUs = performanceMonotonicMicroseconds()

  override init() {
    _ = AppDelegate.nativeEntryUs
    super.init()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
