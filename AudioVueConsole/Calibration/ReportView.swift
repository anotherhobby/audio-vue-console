import ConsoleCore
import SwiftUI
import WebKit

/// A run's HTML report as the host wrote it (`calibration-history`, design D5): fetched by the core,
/// handed to the web view as a string with no base URL, and kept from reaching anything else. A
/// rule list blocks every load, and the delegate allows only the first navigation.
struct ReportView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        context.coordinator.load(html, into: view)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.load(html, into: view)
    }

    /// Loads one report once its rule list is in place, and lets nothing navigate after it.
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        private var shown: String?
        private var allowsNext = false

        func load(_ html: String, into view: WKWebView) {
            guard html != shown else { return }
            shown = html
            Task {
                await Self.blockEverything(view.configuration.userContentController)
                allowsNext = true
                view.loadHTMLString(html, baseURL: nil)
            }
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor action: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard allowsNext else { return .cancel }
            allowsNext = false
            return .allow
        }

        /// Blocks every resource load the report could make; it is self-contained, so none is
        /// wanted.
        private static func blockEverything(_ controller: WKUserContentController) async {
            let rules = #"[{"trigger": {"url-filter": ".*"}, "action": {"type": "block"}}]"#
            do {
                let list = try await WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "BlockEverything", encodedContentRuleList: rules)
                if let list { controller.add(list) }
            } catch {
                // Without the rule list the delegate still allows only the first navigation, and
                // a report loads nothing of its own.
                return
            }
        }
    }
}

/// A run opened on the Calibration page: its report, fetched when opened, or why there is none.
struct RunReport: View {
    let run: RunEntry
    let runs: CalibrationRuns?
    @State private var html: String?
    @State private var failure: String?

    var body: some View {
        Group {
            if let html {
                ReportView(html: html)
            } else if let failure {
                ContentUnavailableView(
                    "Couldn't Read the Report", systemImage: "exclamationmark.triangle",
                    description: Text(failure))
            } else if run.hasReport {
                ProgressView()
            } else {
                ContentUnavailableView(
                    "No Report", systemImage: "doc.text",
                    description: Text("The host has no report for this run."))
            }
        }
        .navigationTitle(run.title)
        .task(id: run.id) { await fetch() }
    }

    private func fetch() async {
        guard run.hasReport, let runs else { return }
        do throws(HostFailure) {
            html = try await runs.report(run)
        } catch {
            failure = ReadFailureText.text(error)
        }
    }
}
