import Testing
@testable import PaikeiCore

/// MJAIサーバとの対話（実装フェーズ7）。自席は絶対座席2、親は絶対座席0で固定する。
/// 座順は反時計回りなので 0=対面 1=上家 2=自分 3=下家（仕様§8.2）。
@Suite("MJAIプロトコルの対話")
struct MJAIプロトコルの対話 {
    static let unknownHand = Array(repeating: "\"?\"", count: 13).joined(separator: ",")

    /// 一気通貫のシャンポン待ちテンパイ（1p / 5s）で配牌された、という設定。
    static let myHand = ["1m", "2m", "3m", "4m", "5m", "6m", "7m", "8m", "9m",
                         "1p", "1p", "5s", "5s"]
        .map { "\"\($0)\"" }.joined(separator: ",")

    static let 対局開始 = #"{"type":"start_game","names":["A","B","C","D"],"id":2}"#
    static let 局開始 = """
        {"type":"start_kyoku","bakaze":"E","dora_marker":"3p","kyoku":1,"honba":0,\
        "kyotaku":1,"oya":0,"scores":[25000,24000,25000,25000],\
        "tehais":[[\(unknownHand)],[\(unknownHand)],[\(myHand)],[\(unknownHand)]]}
        """

    func 対局開始まで() throws -> MjaiSession {
        var session = MjaiSession()
        _ = try session.receive(Self.対局開始)
        _ = try session.receive(Self.局開始)
        return session
    }

    /// 行を順に流し、`SimpleBot` の応答行を集める。
    func 対局(_ lines: [String]) throws -> [String] {
        var session = MjaiSession()
        let bot = SimpleBot()
        var sent: [String] = []
        for line in lines {
            let response: MjaiResponse
            switch try session.receive(line) {
            case .挨拶:
                response = .参加(名前: "Paikei", 部屋: "default")
            default:
                if let timeline = session.timeline,
                   let action = try bot.action(for: .自分, in: timeline) {
                    response = .行動(action)
                } else {
                    response = .なし
                }
            }
            sent.append(try session.line(for: response))
        }
        return sent
    }

    // MARK: - 制御メッセージ

    @Test func 対局開始で自席が決まる() throws {
        var session = MjaiSession()
        #expect(try session.receive(Self.対局開始)
                == .対局開始(名前: ["A", "B", "C", "D"], 自席: 2))
        #expect(session.selfActor == 2)
        #expect(session.names == ["A", "B", "C", "D"])
    }

    @Test func 挨拶には参加を返す() throws {
        var session = MjaiSession()
        #expect(try session.receive(#"{"type":"hello","protocol_version":3}"#) == .挨拶(版: 3))
        #expect(try session.line(for: .参加(名前: "Paikei", 部屋: "default"))
                == #"{"type":"join","name":"Paikei","room":"default"}"#)
    }

    @Test func 局終了でイベント列を捨てる() throws {
        var session = try 対局開始まで()
        #expect(session.timeline != nil)
        #expect(try session.receive(#"{"type":"end_kyoku"}"#) == .局終了)
        #expect(session.timeline == nil)
        #expect(session.state == nil)
    }

    // MARK: - 配牌 → 初期局面

    @Test("配牌は仮定の要らない初期局面になる")
    func 配牌は仮定の要らない初期局面になる() throws {
        let session = try 対局開始まで()
        let state = try #require(session.state)

        #expect(state.場風 == .東)
        #expect(state.局 == 1)
        #expect(state.honba == 0)
        #expect(state.kyotaku == 1)
        #expect(state.doraMarkers == [try Tile.parse("3p")])
        #expect(state.wall == 70)  // 136 - 王牌14 - 配牌52

        // 親が絶対座席0（＝対面）なので、自分は西家。
        #expect(state.players[.対面]?.seat == .東)
        #expect(state.players[.上家]?.seat == .南)
        #expect(state.players[.自分]?.seat == .西)
        #expect(state.players[.下家]?.seat == .北)

        #expect(state.players[.自分]?.hand == (try Tile.parseHand("123456789m11p55s")))
        #expect(state.players[.上家]?.score == 24000)
        // 配牌直後なので「立直していない」と言い切れる（不明ではない）。
        #expect(state.players[.自分]?.riichi == false)
    }

    @Test func 他家の配牌は不明のまま() throws {
        let session = try 対局開始まで()
        #expect(try #require(session.state).players[.下家]?.hand == nil)
    }

    // MARK: - 断るべきところ

    @Test func 自席が決まる前は解釈できない() throws {
        var session = MjaiSession()
        #expect(throws: MjaiSessionError.自席未確定) {
            _ = try session.receive(#"{"type":"tsumo","actor":2,"pai":"1m"}"#)
        }
        #expect(throws: MjaiSessionError.自席未確定) {
            _ = try session.receive(Self.局開始)
        }
    }

    @Test func 局が始まる前の進行イベントは断る() throws {
        var session = MjaiSession()
        _ = try session.receive(Self.対局開始)
        #expect(throws: MjaiSessionError.局外のイベント) {
            _ = try session.receive(#"{"type":"tsumo","actor":2,"pai":"1m"}"#)
        }
    }

    @Test func 既知の状態と矛盾するイベントは断る() throws {
        var session = try 対局開始まで()
        // 手牌に無い牌は切れない（仕様§8.3）。
        #expect(throws: EventApplicationError.self) {
            _ = try session.receive(#"{"type":"dahai","actor":2,"pai":"C","tsumogiri":false}"#)
        }
    }

    // MARK: - 方言の入出力

    @Test("mjai方言でシリアライズして読み直すと同じイベント")
    func mjai方言のラウンドトリップ() throws {
        let format = StreamFormat.mjai(selfActor: 2)
        let events: [Event] = [
            .ツモ(of: .自分, 牌: try Tile.parse("0m")),
            .ツモ(of: .下家, 牌: nil),
            .打牌(of: .自分, 牌: try Tile.parse("1z"), ツモ切り: false),
            .打牌(of: .対面, 牌: try Tile.parse("7z"), ツモ切り: nil),
            .チー(of: .自分, 牌: try Tile.parse("3m"), 手牌から: try Tile.parseHand("45m")),
            .ポン(of: .自分, from: .上家, 牌: try Tile.parse("5p"),
                 手牌から: try Tile.parseHand("05p")),
            .大明槓(of: .下家, from: .対面, 牌: try Tile.parse("2s"),
                   手牌から: try Tile.parseHand("222s")),
            .加槓(of: .上家, 牌: try Tile.parse("5p")),
            .暗槓(of: .自分, 手牌から: try Tile.parseHand("1111z")),
            .立直(of: .自分),
            .立直成立(of: .自分),
            .新ドラ(表示牌: try Tile.parse("4s")),
            .和了(of: .自分, from: .下家, 牌: try Tile.parse("6p")),
            .和了(of: .対面, from: .対面, 牌: nil),
            .流局(理由: .四風連打),
        ]
        for event in events {
            let line = EventCoding.line(for: event, format: format)
            #expect(try EventCoding.event(fromLine: line, format: format) == event,
                    "\(line)")
        }
    }

    @Test func 応答は絶対座席で書き出す() throws {
        let session = try 対局開始まで()
        #expect(try session.line(for: .なし) == #"{"type":"none"}"#)
        #expect(try session.line(for: .行動(.打牌(of: .自分, 牌: try Tile.parse("1z"),
                                              ツモ切り: false)))
                == #"{"type":"dahai","actor":2,"pai":"E","tsumogiri":false}"#)
        // 下家は self+1 なので絶対座席3。
        #expect(try session.line(for: .行動(.ポン(of: .自分, from: .下家,
                                              牌: try Tile.parse("0p"),
                                              手牌から: try Tile.parseHand("55p"))))
                == #"{"type":"pon","actor":2,"target":3,"pai":"5pr","consumed":["5p","5p"]}"#)
    }

    @Test func 自席が決まる前は応答を書けない() {
        let session = MjaiSession()
        #expect(throws: MjaiSessionError.自席未確定) {
            _ = try session.line(for: .行動(.流局(理由: nil)))
        }
    }

    // MARK: - 通しの対局

    @Test("ツモ切りとロンを返しながら一局を進める")
    func 一局を進める() throws {
        let sent = try 対局([
            #"{"type":"hello","protocol_version":3}"#,
            Self.対局開始,
            Self.局開始,
            #"{"type":"tsumo","actor":0,"pai":"?"}"#,
            #"{"type":"dahai","actor":0,"pai":"E","tsumogiri":true}"#,
            #"{"type":"tsumo","actor":1,"pai":"?"}"#,
            #"{"type":"dahai","actor":1,"pai":"S","tsumogiri":true}"#,
            #"{"type":"tsumo","actor":2,"pai":"9s"}"#,          // 自分のツモ
            #"{"type":"dahai","actor":2,"pai":"9s","tsumogiri":true}"#,  // 自分の打牌の反響
            #"{"type":"tsumo","actor":3,"pai":"?"}"#,
            #"{"type":"dahai","actor":3,"pai":"5s","tsumogiri":false}"#, // 当たり牌
        ])

        #expect(sent == [
            #"{"type":"join","name":"Paikei","room":"default"}"#,
            #"{"type":"none"}"#,  // start_game
            #"{"type":"none"}"#,  // start_kyoku
            #"{"type":"none"}"#, #"{"type":"none"}"#,
            #"{"type":"none"}"#, #"{"type":"none"}"#,
            // テンパイを崩さない9sを切る。
            #"{"type":"dahai","actor":2,"pai":"9s","tsumogiri":true}"#,
            // 自分の打牌には応答しない。
            #"{"type":"none"}"#,
            #"{"type":"none"}"#,
            #"{"type":"hora","actor":2,"target":3,"pai":"5s"}"#,
        ])
    }

    @Test func ツモ和了を宣言する() throws {
        let sent = try 対局([
            Self.対局開始,
            Self.局開始,
            #"{"type":"tsumo","actor":2,"pai":"1p"}"#,
        ])
        #expect(sent.last == #"{"type":"hora","actor":2,"target":2,"pai":"1p"}"#)
    }
}

/// 最小の打ち手（`SimpleBot`）の選択そのもの。プロトコルは経由しない。
@Suite("最小の打ち手")
struct 最小の打ち手 {
    let bot = SimpleBot()

    func timeline(hand: String, draw: String? = nil, riichi: Bool = false,
                  claim: ClaimTile? = nil) throws -> GameTimeline {
        GameTimeline(snapshot: GameState(
            場風: .東, 局: 1, honba: 0, kyotaku: 0,
            doraMarkers: [try Tile.parse("3p")], wall: 40,
            players: [
                .自分: PlayerState(seat: .西, hand: try Tile.parseHand(hand),
                                     draw: try draw.map { try Tile.parse($0) },
                                     riichi: riichi, score: 25000),
                .上家: PlayerState(seat: .南),
                .下家: PlayerState(seat: .北),
            ],
            claim: claim))
    }

    @Test func 他家の手番では何もしない() throws {
        #expect(try bot.action(for: .自分, in: timeline(hand: "123456789m11p55s")) == nil)
    }

    @Test func 受け入れが最大の牌を切る() throws {
        // テンパイを崩さない9sだけが正解。
        let t = try timeline(hand: "123456789m11p55s", draw: "9s")
        #expect(try bot.action(for: .自分, in: t)
                == .打牌(of: .自分, 牌: try Tile.parse("9s"), ツモ切り: true))
    }

    @Test func 同じ数字なら赤5を残す() throws {
        // 国士1シャンテン。要らないのは重なった5sで、赤でない方を切る。
        let t = try timeline(hand: "19m19p09s1234567z", draw: "5s")
        #expect(try bot.action(for: .自分, in: t)
                == .打牌(of: .自分, 牌: try Tile.parse("5s"), ツモ切り: true))
    }

    @Test func 立直後はツモ切りしかしない() throws {
        let t = try timeline(hand: "123456789m11p55s", draw: "7z", riichi: true)
        #expect(try bot.action(for: .自分, in: t)
                == .打牌(of: .自分, 牌: try Tile.parse("7z"), ツモ切り: true))
    }

    @Test func 鳴ける形でも鳴かない() throws {
        // 55s があるので5sはポンできるが、ロンできる手なのでロンを選ぶ。
        let ron = try timeline(hand: "123456789m11p55s",
                               claim: ClaimTile(tile: try Tile.parse("5s"), from: .上家))
        #expect(try bot.action(for: .自分, in: ron)
                == .和了(of: .自分, from: .上家, 牌: try Tile.parse("5s")))

        // 和了形になっても役が無ければロンできない。ポンできても鳴かずに見送る。
        let pass = try timeline(hand: "111m456m789m99p33s",
                                claim: ClaimTile(tile: try Tile.parse("9p"), from: .上家))
        #expect(try bot.action(for: .自分, in: pass) == nil)
    }
}
