import ArgumentParser
import Foundation
import PaikeiCore

/// `.paikei` ファイルの読み込みと、ストリーム適用位置の解決（CLI共通）。
enum DocumentLoading {
    /// 入力の種別。**中身で見分ける**のでコマンドを増やさない。
    ///
    /// `.paikei` は1局が単位（仕様§10の論点7）。半荘を1ファイルに落とす表現は
    /// まだ無いので、複数局を流すには MJAI の生ログを使う。
    enum Input {
        /// `.paikei` ドキュメント（1局）。
        case document(GameTimeline)
        /// MJAI 生ログ（JSON Lines）。`start_kyoku` の数だけ局が入っている。
        case mjaiLog([String])
    }

    static func input(at path: String) throws -> Input {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        // `.paikei` の行は `key: value` か `[section]` か `#` コメント。
        // JSON Lines は `{` で始まるので、最初の中身のある行で判別できる。
        let first = text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") }
        if first?.hasPrefix("{") == true {
            return .mjaiLog(text.split(separator: "\n").map(String.init))
        }
        return .document(try GameTimeline.parse(text))
    }

    static func document(at path: String) throws -> GameTimeline {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return try GameTimeline.parse(text)
    }

    /// `steps` 番目まで適用した状態を返す。省略時は末尾（仕様§8.3の既定）。
    static func state(at path: String, steps: Int?) throws -> GameState {
        let doc = try document(at: path)
        if let steps, !(0...doc.events.count).contains(steps) {
            throw ValidationError(
                "--at \(steps) が範囲外です（このファイルのイベントは \(doc.events.count) 個）")
        }
        do {
            return try doc.state(at: steps)
        } catch let error as EventApplicationError {
            throw ValidationError("ストリームの適用に失敗しました: \(error)")
        }
    }
}
