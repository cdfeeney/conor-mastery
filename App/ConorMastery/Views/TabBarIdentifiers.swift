import SwiftUI
import UIKit

/// Gives the system tab bar buttons stable identifiers ("tab-Today") for UI tests; SwiftUI's `Tab` has no API for it.
struct TabBarIdentifiers: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { Probe() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Probe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // The tab bar controller is attached after this view; tag on the next turn of the run loop.
            Task { @MainActor [weak self] in self?.tagTabs() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            tagTabs()
        }

        private func tagTabs() {
            guard let root = window?.rootViewController else { return }
            for bar in Self.tabBars(in: root) {
                for item in bar.items ?? [] where item.accessibilityIdentifier == nil {
                    item.accessibilityIdentifier = item.title.map { "tab-\($0)" }
                }
            }
        }

        private static func tabBars(in controller: UIViewController) -> [UITabBar] {
            let own = (controller as? UITabBarController).map { [$0.tabBar] } ?? []
            return own + controller.children.flatMap { tabBars(in: $0) }
        }
    }
}
