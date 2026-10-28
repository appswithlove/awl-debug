import SwiftUI

struct LogDetailView: View {
    let log: NetworkLog

    @State private var isShowingRaw = false

    var body: some View {
        List {
            OverviewSection
            HeadersSection(title: LS.Network.requestHeaders, headers: log.requestHeaders)
            BodySection(title: LS.Network.requestBody, body: log.requestBody)
            HeadersSection(title: LS.Network.responseHeaders, headers: log.responseHeaders)
            BodySection(title: LS.Network.responseBody, body: log.responseBody)
        }
        .listStyle(.insetGrouped)
        .panelPage("\(log.method) \(log.statusCode)") {
            ActionsMenu
        }
    }

    @ViewBuilder private var ActionsMenu: some View {
        Menu {
            Button(LS.Network.copyUrl) {
                UIPasteboard.general.string = log.url
            }
            Button(LS.Network.copyCurl) {
                UIPasteboard.general.string = log.curlCommand
            }
            Button(LS.Network.copyResponse) {
                UIPasteboard.general.string = log.responseBody?.text ?? LS.Network.noBody
            }
            .disabled(log.responseBody == nil)
            ShareLink(LS.Network.share, item: log.exportText)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder private var OverviewSection: some View {
        Section {
            OverviewRow(title: LS.Network.url, value: log.url)
            OverviewRow(title: LS.Network.method, value: log.method)
            OverviewRow(title: LS.Network.status, value: statusText)
            OverviewRow(title: LS.Network.start, value: log.date.formatted(date: .numeric, time: .standard))
            OverviewRow(title: LS.Network.duration, value: "\(log.duration) ms")
            OverviewRow(title: LS.Network.requestSize, value: ByteCountFormatter.string(fromByteCount: Int64(log.requestBytes), countStyle: .file))
            OverviewRow(title: LS.Network.responseSize, value: ByteCountFormatter.string(fromByteCount: Int64(log.responseBytes), countStyle: .file))
            if let errorDescription = log.errorDescription {
                OverviewRow(title: LS.Network.error, value: errorDescription)
            }
            if log.redactedCount > 0 {
                Text(LS.Network.redactedCount(log.redactedCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(LS.Network.overview)
        }
    }

    private var statusText: String {
        guard log.statusCode > 0 else { return LS.Network.failed }
        return "\(log.statusCode)"
    }

    private func OverviewRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }

    private func HeadersSection(title: String, headers: [NetworkLog.Header]) -> some View {
        Section {
            if headers.isEmpty {
                Text(LS.Strings.unknownValue)
                    .foregroundStyle(.secondary)
            }
            ForEach(headers, id: \.self) { header in
                OverviewRow(title: header.name, value: header.value)
            }
        } header: {
            Text(title)
        }
    }

    private func BodySection(title: String, body: NetworkLog.Body?) -> some View {
        Section {
            if let body = body {
                if body.isText, NetworkRedactor.isJSON(NetworkRedactor.mediaType(of: body.contentType)) {
                    Toggle(LS.Network.raw, isOn: $isShowingRaw)
                }
                Text(displayText(of: body))
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                if body.truncated {
                    Text(LS.Network.truncated(body.originalBytes))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(LS.Network.noBody)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(title)
        }
    }

    private func displayText(of body: NetworkLog.Body) -> String {
        guard !isShowingRaw, body.isText, !body.truncated,
              NetworkRedactor.isJSON(NetworkRedactor.mediaType(of: body.contentType)),
              let json = try? JSONSerialization.jsonObject(with: Data(body.text.utf8), options: .fragmentsAllowed),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]) else {
            return body.text
        }
        return String(decoding: pretty, as: UTF8.self)
    }
}
