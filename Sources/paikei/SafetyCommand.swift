import ArgumentParser
import Foundation
import PaikeiCore

/// 自分の手牌の各牌について、対象プレイヤーへの安全度を表示する。
struct SafetyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "safety",
        abstract: "対象プレイヤーへの安全度（現物/スジ/壁）を表示する",
        discussion: """
            対象を省略するとリーチしている他家を対象にする。
            スジ・壁は両面待ちを否定するだけで、絶対安全は現物のみ。
            """
    )

    @Argument(help: ".paikei ファイルへのパス")
    var path: String

    @Argument(help: "対象プレイヤー（shimocha/toimen/kamicha）。省略時はリーチ者")
    var target: String?

    @Option(name: .long, help: "ストリームを N イベント目まで適用した状態で解析（省略時は末尾）")
    var at: Int?

    func run() throws {
        let state = try DocumentLoading.state(at: path, steps: at)

        do {
            print(try SafetyReport.text(for: state, target: target))
        } catch let error as ReportError {
            throw ValidationError(error.description)
        }
    }
}
