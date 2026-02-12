//
//  ShareSheetHelper.swift
//  RealRehabPractice
//
//  Presents the iOS share sheet with a message and deep link for sharing an access code.
//

import SwiftUI
import UIKit

enum ShareSheetHelper {
    private static let linkMessage = "Link to my profile on RealRehab. Use this code to connect:"
    
    /// Builds the share message and URL for an access code.
    static func activityItems(for code: String) -> [Any] {
        let message = "\(linkMessage) \(code)"
        let urlString = "realrehab://link?code=\(code)"
        guard let url = URL(string: urlString) else {
            return [message]
        }
        return [message, url]
    }
    
    /// Presents the system share sheet with the given access code. Call from the main thread.
    static func presentShareSheet(code: String, from viewController: UIViewController? = nil, onComplete: (() -> Void)? = nil) {
        let items = activityItems(for: code)
        let vc = viewController ?? topViewController()
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            onComplete?()
        }
        vc?.present(activityVC, animated: true)
    }
    
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController { return topViewController(base: selected) }
        if let presented = base?.presentedViewController { return topViewController(base: presented) }
        return base
    }
}
