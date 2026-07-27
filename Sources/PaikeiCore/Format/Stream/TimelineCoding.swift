/// `.paikei` テキスト ⇄ `GameTimeline` の相互変換（仕様§8）。
///
/// 時系列そのものはドメイン型（`Model/GameTimeline.swift`）で、
/// ここはテキスト表現だけを扱う。依存は Format → ドメインの一方向。
extension GameTimeline {
    /// テキスト全体をパースする。`[stream]` が無ければイベントは空。
    public static func parse(_ text: String) throws -> GameTimeline {
        // スナップショット部は SnapshotParser 自身が [stream] で読み止める。
        let snapshot = try SnapshotParser.parse(text)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let headerIndex = lines.firstIndex(where: {
            $0.trimmingWhitespace().hasPrefix("[stream]")
        }) else {
            return GameTimeline(snapshot: snapshot)
        }

        let format = try parseHeader(lines[headerIndex].trimmingWhitespace())
        var events: [Event] = []
        for line in lines[(headerIndex + 1)...] {
            let trimmed = line.trimmingWhitespace()
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            events.append(try EventCoding.event(fromLine: String(trimmed), format: format))
        }
        return GameTimeline(snapshot: snapshot, events: events)
    }

    /// 正規化シリアライズ。ストリームは常に paikei 方言で書く。
    public func serialized() -> String {
        var text = snapshot.serialized()
        guard !events.isEmpty else { return text }
        text += "\n[stream] format=paikei\n"
        text += events.map(EventCoding.line(for:)).joined(separator: "\n") + "\n"
        return text
    }

    /// `[stream] format=mjai self_actor=2` を解釈する。行末コメントは無視する（§3）。
    private static func parseHeader(_ line: Substring) throws -> StreamFormat {
        let body = line.prefix(while: { $0 != "#" }).dropFirst("[stream]".count)
        var attributes: [String: String] = [:]
        for token in body.split(whereSeparator: { $0.isWhitespace }) {
            let pair = token.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else {
                throw StreamParseError.不正なヘッダ(String(line))
            }
            attributes[String(pair[0])] = String(pair[1])
        }

        switch attributes["format"] ?? "paikei" {
        case "paikei":
            return .paikei
        case "mjai":
            // 絶対座席とカメラ相対の対応付けに必須（仕様§8.2）。
            guard let text = attributes["self_actor"] else {
                throw StreamParseError.self_actor欠落
            }
            guard let seat = Int(text), (0...3).contains(seat) else {
                throw StreamParseError.不正な値(フィールド: "self_actor", 値: text)
            }
            return .mjai(selfActor: seat)
        case let other:
            throw StreamParseError.未知のformat(other)
        }
    }
}
