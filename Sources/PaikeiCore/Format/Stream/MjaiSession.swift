import Foundation

/// MJAIサーバから届く1行の意味（実装フェーズ7）。
///
/// 局の進行そのものは既存の `Event` 語彙（仕様§8.1）で表す。ここに追加されるのは
/// **局をまたぐ制御**だけで、`Event` は汚さない — 局の切れ目は状態遷移ではなく
/// 新しい `GameTimeline` の始まりだから。
public enum MjaiMessage: Sendable, Equatable {
    /// 接続の挨拶。`参加` を返すのが作法。
    case 挨拶(版: Int)
    /// 対局開始。自分の絶対座席がここで確定する。
    case 対局開始(名前: [String], 自席: Int)
    /// 配牌。初期局面（t0）に変換済み。
    case 局開始(GameState)
    /// 局の進行。
    case 進行(Event)
    case 局終了
    case 対局終了
    /// サーバ側のエラー通知。
    case エラー(String)
}

/// bot がサーバへ返す1行。
public enum MjaiResponse: Sendable, Equatable {
    /// 何もしない（`{"type":"none"}`）。スルーもこれ。
    case なし
    /// 卓への参加表明（`挨拶` への応答）。
    case 参加(名前: String, 部屋: String)
    case 行動(Event)
}

/// MJAIプロトコルの進行に関するエラー。
public enum MjaiSessionError: Error, Equatable, Sendable {
    /// `start_game` より前にイベントが来た（絶対座席を解決できない）。
    case 自席未確定
    /// `start_kyoku` より前に局の進行イベントが来た。
    case 局外のイベント
}

/// MJAIサーバとの対話状態（実装フェーズ7）。
///
/// 入出力（stdin/stdout・ソケット）は持たない。1行を受け取って解釈し、進行中の局を
/// `GameTimeline` として積むだけの純粋な状態機械なので、対局の記録をそのまま
/// テストのフィクスチャにできる。
///
/// 応答の優先順位（ロン > ポン/カン > チー、頭ハネ）はサーバの裁定なので扱わない。
/// bot は自分の希望を1つ返すだけで、通ったかどうかは次のイベントで分かる。
public struct MjaiSession: Sendable {
    /// 自分の絶対座席。`対局開始` で確定する。
    public private(set) var selfActor: Int?
    /// 対局者名（絶対座席順）。
    public private(set) var names: [String] = []
    /// 進行中の局。局の外では nil。
    public private(set) var timeline: GameTimeline?
    /// 進行中の局の現在状態。`timeline` を毎回再生せずに済むよう逐次更新する。
    public private(set) var state: GameState?

    public init(selfActor: Int? = nil) {
        self.selfActor = selfActor
    }

    /// 1行を解釈し、進行中の局へ反映して、解釈結果を返す。
    ///
    /// イベントが既知の状態と矛盾していれば `EventApplicationError` を投げる（仕様§8.3）。
    /// その場合セッションは更新されない。
    public mutating func receive(_ line: String) throws -> MjaiMessage {
        let message = try decode(line)
        switch message {
        case let .対局開始(names, 席風):
            self.names = names
            selfActor = 席風
            timeline = nil
            state = nil
        case let .局開始(snapshot):
            timeline = GameTimeline(snapshot: snapshot)
            state = snapshot
        case let .進行(event):
            guard var timeline, let current = state else {
                throw MjaiSessionError.局外のイベント
            }
            state = try current.applying(event)
            timeline.events.append(event)
            self.timeline = timeline
        case .局終了, .対局終了:
            timeline = nil
            state = nil
        case .挨拶, .エラー:
            break
        }
        return message
    }

    /// 応答を1行のJSONにする。座席の解決に `selfActor` が要る。
    public func line(for response: MjaiResponse) throws -> String {
        switch response {
        case .なし:
            return #"{"type":"none"}"#
        case let .参加(name, room):
            return #"{"type":"join","name":"\#(escaped(name))","room":"\#(escaped(room))"}"#
        case let .行動(event):
            guard let selfActor else { throw MjaiSessionError.自席未確定 }
            return EventCoding.line(for: event, format: .mjai(selfActor: selfActor))
        }
    }

    // MARK: - 解釈

    private func decode(_ line: String) throws -> MjaiMessage {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)),
              let fields = object as? [String: Any],
              let type = fields["type"] as? String else {
            throw StreamParseError.不正なJSON(line)
        }

        switch type {
        case "hello":
            return .挨拶(版: fields["protocol_version"] as? Int ?? 0)
        case "start_game":
            guard let seat = fields["id"] as? Int, (0...3).contains(seat) else {
                throw StreamParseError.不正な値(フィールド: "id", 値: "\(fields["id"] ?? "")")
            }
            return .対局開始(名前: fields["names"] as? [String] ?? [], 自席: seat)
        case "start_kyoku":
            guard let selfActor else { throw MjaiSessionError.自席未確定 }
            return .局開始(try MjaiKyoku.snapshot(from: fields, selfActor: selfActor))
        case "end_kyoku":
            return .局終了
        case "end_game":
            return .対局終了
        case "error":
            return .エラー(fields["message"] as? String ?? line)
        default:
            guard let selfActor else { throw MjaiSessionError.自席未確定 }
            return .進行(try EventCoding.event(
                fromLine: line, format: .mjai(selfActor: selfActor)))
        }
    }

    /// 名前・部屋名はサーバ側から来た文字列を含み得るので、最低限の脱出をする。
    private func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
