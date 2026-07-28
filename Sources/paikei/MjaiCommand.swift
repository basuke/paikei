import ArgumentParser
import Foundation
import PaikeiCore

/// MJAIプロトコルのbotとして標準入出力で対局する（実装フェーズ7）。
struct MjaiCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mjai",
        abstract: "MJAIプロトコルのbotとして標準入出力で対局する",
        discussion: """
            1行1メッセージのJSON Linesを標準入力から読み、応答を標準出力へ返す。
            mjai.appシミュレータのパイプに直接つなぐ用途を想定している。

            解釈できない行や矛盾したイベントは標準エラーへ報告し、{"type":"none"} を
            返して対局は続ける（1局を落とすより、どこで壊れたかを残す方を採る）。
            """)

    @Option(name: .long, help: "サーバに名乗る名前")
    var name = "Paikei"

    @Option(name: .long, help: "参加する部屋")
    var room = "default"

    @Flag(name: .long, help: "送受信した行を標準エラーへ書き出す")
    var verbose = false

    func run() throws {
        var session = MjaiSession()
        let bot = SimpleBot()

        while let line = readLine(strippingNewline: true) {
            let received = line.trimmingCharacters(in: .whitespaces)
            if received.isEmpty { continue }
            if verbose { report("<- \(received)") }

            let (response, finished) = respond(to: received, session: &session, bot: bot)
            let sent = (try? session.line(for: response)) ?? #"{"type":"none"}"#

            // `print` はパイプ越しだと全バッファリングされ、応答が届かない。
            // 1手ごとに確実に送り出すため、直接書く。
            FileHandle.standardOutput.write(Data((sent + "\n").utf8))
            if verbose { report("-> \(sent)") }
            if finished { break }
        }
    }

    /// 1行を処理して、返す応答と「対局を終えるか」を決める。
    private func respond(
        to line: String, session: inout MjaiSession, bot: some Bot
    ) -> (MjaiResponse, Bool) {
        do {
            switch try session.receive(line) {
            case .挨拶:
                return (.参加(名前: name, 部屋: room), false)
            case .対局終了:
                return (.なし, true)
            case let .エラー(text):
                report("サーバがエラーを返しました: \(text)")
                return (.なし, true)
            case .対局開始, .局開始, .局終了, .進行:
                guard let timeline = session.timeline,
                      let action = try bot.action(for: .自分, in: timeline) else {
                    return (.なし, false)
                }
                return (.行動(action), false)
            }
        } catch {
            report("処理できませんでした: \(error) — \(line)")
            return (.なし, false)
        }
    }

    private func report(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
