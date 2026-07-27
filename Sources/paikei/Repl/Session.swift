import Foundation
import PaikeiCore

/// REPL が保持する状態。初期局面 + イベント列 + 適用位置（仕様§8.4）。
///
/// 遷移コマンドはイベントを生成して `document.events` に追記するため、
/// セッションの中身がそのまま `.paikei` として保存できる。
struct Session {
    private(set) var document: GameTimeline
    /// t0 から何イベント適用した時点を見ているか。
    private(set) var position: Int
    /// 直近の `load` / `save` のパス。`save` の既定値に使う。
    var path: String?

    private(set) var state: GameState

    init(document: GameTimeline = GameTimeline(snapshot: GameState()), path: String? = nil) throws {
        self.document = document
        self.position = document.events.count
        self.path = path
        self.state = try document.state()
    }

    var eventCount: Int { document.events.count }

    // MARK: - 位置の移動

    enum SeekError: Error, CustomStringConvertible {
        case outOfRange(requested: Int, available: Int)

        var description: String {
            switch self {
            case let .outOfRange(requested, available):
                "t\(requested) は範囲外です（イベントは \(available) 個）"
            }
        }
    }

    mutating func seek(to newPosition: Int) throws {
        guard (0...document.events.count).contains(newPosition) else {
            throw SeekError.outOfRange(requested: newPosition, available: document.events.count)
        }
        state = try document.state(at: newPosition)
        position = newPosition
    }

    // MARK: - イベントの追加

    /// イベントを適用して履歴に追記する。
    ///
    /// 巻き戻した位置で操作した場合、その先の履歴は捨てる（分岐は持たない）。
    mutating func apply(_ event: Event) throws {
        let next = try state.applying(event)
        document.events = Array(document.events.prefix(position)) + [event]
        position = document.events.count
        state = next
    }

    // MARK: - 読み書き

    mutating func load(_ path: String) throws {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        document = try GameTimeline.parse(text)
        position = document.events.count
        state = try document.state()
        self.path = path
    }

    /// 現在のドキュメント（初期局面 + 全イベント）を書き出す。
    ///
    /// 巻き戻した位置で保存しても、履歴は全て残す（`seek` は見る位置を変えるだけ）。
    func save(to path: String) throws {
        try document.serialized().write(toFile: path, atomically: true, encoding: .utf8)
    }
}
