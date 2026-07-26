/// `.paikei` ドキュメント全体 = スナップショット（t0）+ 任意のイベントストリーム（仕様§8）。
public struct PaikeiDocument: Sendable, Equatable {
    /// 初期局面 t0。
    public var snapshot: GameState
    /// t0 から順に適用するイベント列。
    public var events: [Event]

    public init(snapshot: GameState, events: [Event] = []) {
        self.snapshot = snapshot
        self.events = events
    }

    /// テキスト全体をパースする。`[stream]` が無ければイベントは空。
    public static func parse(_ text: String) throws -> PaikeiDocument {
        // スナップショット部は SnapshotParser 自身が [stream] で読み止める。
        let snapshot = try SnapshotParser.parse(text)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let headerIndex = lines.firstIndex(where: {
            $0.trimmingWhitespace().hasPrefix("[stream]")
        }) else {
            return PaikeiDocument(snapshot: snapshot)
        }

        let format = try parseHeader(lines[headerIndex].trimmingWhitespace())
        var events: [Event] = []
        for line in lines[(headerIndex + 1)...] {
            let trimmed = line.trimmingWhitespace()
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            events.append(try EventCoding.event(fromLine: String(trimmed), format: format))
        }
        return PaikeiDocument(snapshot: snapshot, events: events)
    }

    /// 正規化シリアライズ。ストリームは常に paikei 方言で書く。
    public func serialized() -> String {
        var text = snapshot.serialized()
        guard !events.isEmpty else { return text }
        text += "\n[stream] format=paikei\n"
        text += events.map(EventCoding.line(for:)).joined(separator: "\n") + "\n"
        return text
    }

    /// 適用ステップ数が範囲外。
    public struct StepOutOfRange: Error, Equatable, Sendable {
        public let requested: Int
        public let available: Int
    }

    /// t0 にイベントを `steps` 個適用した状態。`steps` が nil なら末尾（既定、仕様§8.3）。
    public func state(at steps: Int? = nil) throws -> GameState {
        let count = steps ?? events.count
        guard count >= 0, count <= events.count else {
            throw StepOutOfRange(requested: count, available: events.count)
        }
        return try snapshot.applying(Array(events.prefix(count)))
    }

    // MARK: - ヘッダ

    /// `[stream] format=mjai self_actor=2` を解釈する。
    private static func parseHeader(_ line: Substring) throws -> StreamFormat {
        var attributes: [String: String] = [:]
        for token in line.dropFirst("[stream]".count).split(whereSeparator: { $0.isWhitespace }) {
            let pair = token.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else {
                throw StreamParseError.malformedHeader(String(line))
            }
            attributes[String(pair[0])] = String(pair[1])
        }

        switch attributes["format"] ?? "paikei" {
        case "paikei":
            return .paikei
        case "mjai":
            // 絶対座席とカメラ相対の対応付けに必須（仕様§8.2）。
            guard let text = attributes["self_actor"] else {
                throw StreamParseError.missingSelfActor
            }
            guard let seat = Int(text), (0...3).contains(seat) else {
                throw StreamParseError.invalidValue(field: "self_actor", value: text)
            }
            return .mjai(selfActor: seat)
        case let other:
            throw StreamParseError.unknownFormat(other)
        }
    }
}
