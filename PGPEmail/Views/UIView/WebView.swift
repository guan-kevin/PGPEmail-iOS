//
//  WebView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/11/21.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    var text: String
    @Binding var showImage: Bool
    @Binding var filterOn: Bool
    @Binding var loading: Bool

    var requestToLoad: ((String) -> Void)? = nil

    func makeCoordinator() -> WebView.Coordinator {
        Coordinator(self, loading: $loading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsLinkPreview = false
        webView.isOpaque = false

        return webView
    }

    func onRequestToLoad(result: ((String) -> Void)?) -> some View {
        var copy = self
        copy.requestToLoad = result
        return copy
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastFilterOn == nil || context.coordinator.lastShowImage == nil || context.coordinator.lastShowImage != showImage || context.coordinator.lastFilterOn != filterOn else {
            return
        }

        webView.navigationDelegate = context.coordinator
        context.coordinator.lastFilterOn = filterOn
        context.coordinator.lastShowImage = showImage

        webView.backgroundColor = filterOn ? .black : .white
        webView.scrollView.backgroundColor = filterOn ? .black : .white

        if filterOn {
            let source = """
              var style = document.createElement('style');
              style.innerHTML = '\(cssScript)';
              document.head.appendChild(style);
            """
            let userScript = WKUserScript(source: source,
                                          injectionTime: .atDocumentEnd,
                                          forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(userScript)
        } else {
            webView.configuration.userContentController.removeAllUserScripts()
        }

        if showImage {
            webView.configuration.userContentController.removeAllContentRuleLists()
            webView.loadHTMLString(text, baseURL: nil)
        } else {
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "ContentBlockingRules",
                encodedContentRuleList: blockRules) { contentRuleList, error in

                    if error != nil {
                        return
                    }

                    webView.configuration.userContentController.add(contentRuleList!)
                    webView.loadHTMLString(text, baseURL: nil)
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        @Binding var loading: Bool

        var lastFilterOn: Bool?
        var lastShowImage: Bool?

        init(_ parent: WebView, loading: Binding<Bool>) {
            self.parent = parent
            self._loading = loading
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                if url == "about:blank" {
                    decisionHandler(.allow)
                } else {
                    parent.requestToLoad?(url)
                    decisionHandler(.cancel)
                }

                return
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loading = false
        }
    }

    let blockRules = """
       [
           {
               "trigger": {
                   "url-filter": ".*"
               },
               "action": {
                   "type": "block"
               }
           },
           {
               "trigger": {
                   "url-filter": "file://.*"
               },
               "action": {
                   "type": "ignore-previous-rules"
               }
           }
       ]
    """

    let cssScript = "html {filter: invert(100%);} img {filter: invert(100%);}"
}
