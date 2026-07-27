import ArgumentParser
import Foundation
import PaikeiCore

/// 自分の手牌のシャンテン数と、受け入れ（13枚形）または何切る（14枚形）を表示する。
struct ShantenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shanten",
        abstract: "自分の手牌のシャンテン数と受け入れ/何切るを表示"
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Option(name: .shortAndLong, help: "何切るで表示する打牌候補の数")
    var top: Int = 6

    @Option(name: .long, help: "ストリームを N イベント目まで適用した状態で解析（省略時は末尾）")
    var at: Int?

    func run() throws {
        let state = try DocumentLoading.state(at: path, steps: at)
        do {
            print(try ShantenReport.text(for: state, top: top))
        } catch let error as ReportError {
            throw ValidationError(error.description)
        }
    }
}
