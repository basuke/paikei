import ArgumentParser
import Foundation
import PaikeiCore

/// `.paikei` ファイルの読み込みと、ストリーム適用位置の解決（CLI共通）。
enum DocumentLoading {
    static func document(at path: String) throws -> PaikeiDocument {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return try PaikeiDocument.parse(text)
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
