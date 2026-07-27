import Testing
@testable import PaikeiCore

@Suite("ストリーム: イベントの JSON Lines (§8.1)")
struct ストリームのJSONLines {
    @Test("全イベント種別が paikei 方言でラウンドトリップする")
    func 全イベント種別がpaikei方言でラウンドトリップする() throws {
        let events: [Event] = [
            .ツモ(手番: .myself, 牌: try Tile.parse("6s")),
            .ツモ(手番: .toimen, 牌: nil),
            .打牌(手番: .myself, 牌: try Tile.parse("1z"), ツモ切り: false),
            .打牌(手番: .kamicha, 牌: try Tile.parse("0p"), ツモ切り: true),
            .打牌(手番: .toimen, 牌: try Tile.parse("9m"), ツモ切り: nil),
            .チー(手番: .myself, 牌: try Tile.parse("4m"), 手牌から: try Tile.parseHand("35m")),
            .ポン(手番: .shimocha, 相手: .toimen, 牌: try Tile.parse("5p"),
                 手牌から: try Tile.parseHand("05p")),
            .大明槓(手番: .myself, 相手: .kamicha, 牌: try Tile.parse("9s"),
                       手牌から: try Tile.parseHand("999s")),
            .加槓(手番: .myself, 牌: try Tile.parse("5s")),
            .暗槓(手番: .toimen, 手牌から: try Tile.parseHand("1111z")),
            .立直(手番: .shimocha),
            .立直成立(手番: .shimocha),
            .新ドラ(表示牌: try Tile.parse("3p")),
            .和了(手番: .myself, 相手: .toimen, 牌: try Tile.parse("1m")),
            .和了(手番: .myself, 相手: .myself, 牌: nil),
            .流局,
        ]
        for event in events {
            let line = EventCoding.line(for: event)
            #expect(try EventCoding.event(fromLine: line, format: .paikei) == event,
                    "round-trip failed: \(line)")
        }
    }

    @Test("仕様§8の例をパースする")
    func 仕様8の例をパースする() throws {
        let line = #"{"type":"pon","actor":"toimen","target":"self","pai":"1z","consumed":["1z","1z"]}"#
        let event = try EventCoding.event(fromLine: line, format: .paikei)
        #expect(event == .ポン(手番: .toimen, 相手: .myself,
                              牌: try Tile.parse("1z"),
                              手牌から: try Tile.parseHand("11z")))
    }

    @Test func 不正な行は型付きエラー() throws {
        #expect(throws: StreamParseError.self) {
            _ = try EventCoding.event(fromLine: "not json", format: .paikei)
        }
        #expect(throws: StreamParseError.unknownEventType("start_kyoku")) {
            _ = try EventCoding.event(fromLine: #"{"type":"start_kyoku"}"#, format: .paikei)
        }
        #expect(throws: StreamParseError.missingField("pai", eventType: "dahai")) {
            _ = try EventCoding.event(fromLine: #"{"type":"dahai","actor":"self"}"#, format: .paikei)
        }
    }
}

@Suite("ストリーム: mjai 方言 (§8.2)")
struct ストリームmjai方言 {
    @Test func MJAI牌表記の相互変換() throws {
        let pairs: [(String, String)] = [
            ("1m", "1m"), ("9s", "9s"), ("5mr", "0m"), ("5pr", "0p"),
            ("E", "1z"), ("S", "2z"), ("W", "3z"), ("N", "4z"),
            ("P", "5z"), ("F", "6z"), ("C", "7z"),
        ]
        for (mjai, mpsz) in pairs {
            let tile = try #require(Tile(mjai: mjai), "parse \(mjai)")
            #expect(tile.mpsz == mpsz)
            #expect(tile.mjaiNotation == mjai)
        }
        #expect(Tile(mjai: "0m") == nil)   // MJAI に 0 表記はない
        #expect(Tile(mjai: "5zr") == nil)  // 字牌に赤はない
    }

    @Test("絶対座席がカメラ相対に解決される（仕様§8.2の例）")
    func 絶対座席がカメラ相対に解決される() throws {
        let format = StreamFormat.mjai(selfActor: 2)
        let tsumo = try EventCoding.event(
            fromLine: #"{"type":"tsumo","actor":2,"pai":"W"}"#, format: format)
        #expect(tsumo == .ツモ(手番: .myself, 牌: try Tile.parse("3z")))

        let pon = try EventCoding.event(
            fromLine: #"{"type":"pon","actor":3,"target":0,"pai":"5pr","consumed":["5p","5p"]}"#,
            format: format)
        #expect(pon == .ポン(手番: .shimocha, 相手: .toimen,
                            牌: Tile(suit: .筒子, rank: 5, isRed: true)!,
                            手牌から: try Tile.parseHand("55p")))
    }
}

@Suite("ストリーム: ドキュメント (§8)")
struct ストリームドキュメント {
    let snapshotText = """
        wall: 42

        [self] seat=E
        hand: 123m456m789p55s11z
        score: 25000
        """

    @Test("[stream] が無ければイベントは空")
    func streamが無ければイベントは空() throws {
        let doc = try PaikeiDocument.parse(snapshotText)
        #expect(doc.events.isEmpty)
        #expect(try doc.state() == doc.snapshot)
    }

    @Test("パース → 適用。コメントと空行は無視")
    func パース適用コメントと空行は無視() throws {
        let text = snapshotText + """


        [stream] format=paikei
        # コメント行
        {"type":"tsumo","actor":"self","pai":"6s"}

        {"type":"dahai","actor":"self","pai":"1z","tsumogiri":false}
        """
        let doc = try PaikeiDocument.parse(text)
        #expect(doc.events.count == 2)

        let t0 = try doc.state(at: 0)
        #expect(t0 == doc.snapshot)
        let t1 = try doc.state(at: 1)
        #expect(t1.players[.myself]?.draw == Tile(suit: .索子, rank: 6))
        let final = try doc.state()  // 既定は末尾（§8.3）
        #expect(final.players[.myself]?.river.count == 1)
        #expect(final.wall == 41)
    }

    @Test func 範囲外のステップは型付きエラー() throws {
        let doc = try PaikeiDocument.parse(snapshotText)
        #expect(throws: PaikeiDocument.StepOutOfRange(requested: 5, available: 0)) {
            _ = try doc.state(at: 5)
        }
    }

    @Test func ドキュメント全体がラウンドトリップする() throws {
        let text = snapshotText + """


        [stream] format=paikei
        {"type":"tsumo","actor":"self","pai":"6s"}
        {"type":"reach","actor":"self"}
        {"type":"dahai","actor":"self","pai":"6s","tsumogiri":true}
        {"type":"reach_accepted","actor":"self"}
        """
        let once = try PaikeiDocument.parse(text)
        let twice = try PaikeiDocument.parse(once.serialized())
        #expect(once == twice)
    }

    @Test("[stream] ヘッダの行末コメントは無視する（§3のコメント規則）")
    func streamヘッダの行末コメントは無視する() throws {
        let doc = try PaikeiDocument.parse(snapshotText + """


            [stream] format=mjai self_actor=2  # 自分は絶対座席2
            {"type":"tsumo","actor":2,"pai":"6s"}
            """)
        #expect(doc.events == [.ツモ(手番: .myself, 牌: try Tile.parse("6s"))])
    }

    @Test("mjai は self_actor が必須、未知の format はエラー")
    func ヘッダのformat検証() throws {
        #expect(throws: StreamParseError.missingSelfActor) {
            _ = try PaikeiDocument.parse(snapshotText + "\n[stream] format=mjai\n")
        }
        #expect(throws: StreamParseError.unknownFormat("tenhou")) {
            _ = try PaikeiDocument.parse(snapshotText + "\n[stream] format=tenhou\n")
        }
    }

    @Test("from-mjai フィクスチャ: mjai ストリームを再生できる")
    func mjaiストリームを再生できる() throws {
        let doc = try PaikeiDocument.parse(loadFixture("from-mjai"))
        #expect(!doc.events.isEmpty)

        let final = try doc.state()
        // 最初のイベントで claim_tile(1m) がスルーされ、対面の河に確定する。
        #expect(final.claim == nil)
        #expect(final.players[.toimen]?.river.last?.tile == Tile(suit: .萬子, rank: 1))
    }
}
