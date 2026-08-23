import Foundation

enum AppBuildMode {
#if LOCAL_ONLY
    static let isLocalOnly = true
#else
    static let isLocalOnly = false
#endif
}
