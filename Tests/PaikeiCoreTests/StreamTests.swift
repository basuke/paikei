import Testing
@testable import PaikeiCore

@Suite("ストリーム: イベントの JSON Lines (§8.1)")
struct EventCodingTests {
    @Test("全イベント種別が paikei 方言でラウンドトリップする")
    func roundTrip() throws {
        let events: [Event] = [
            .tsumo(actor: .myself, tile: try Tile.parse("6s")),
            .tsumo(actor: .toimen, tile: nil),
            .dahai(actor: .myself, tile: try Tile.parse("1z"), tsumogiri: false),
            .dahai(actor: .kamicha, tile: try Tile.parse("0p"), tsumogiri: true),
            .dahai(actor: .toimen, tile: try Tile.parse("9m"), tsumogiri: nil),
            .chi(actor: .myself, tile: try Tile.parse("4m"), consumed: try Tile.parseHand("35m")),
            .pon(actor: .shimocha, target: .toimen, tile: try Tile.parse("5p"),
                 consumed: try Tile.parseHand("05p")),
            .daiminkan(actor: .myself, target: .kamicha, tile: try Tile.parse("9s"),
                       consumed: try Tile.parseHand("999s")),
            .kakan(actor: .myself, tile: try Tile.parse("5s")),
            .ankan(actor: .toimen, consumed: try Tile.parseHand("1111z")),
            .reach(actor: .shimocha),
            .reachAccepted(actor: .shimocha),
            .dora(marker: try Tile.parse("3p")),
            .hora(actor: .myself, target: .toimen, tile: try Tile.parse("1m")),
            .hora(actor: .myself, target: .myself, tile: nil),
            .ryukyoku,
        ]
        for event in events {
            let line = EventCoding.line(for: event)
            #expect(try EventCoding.event(fromLine: line, format: .paikei) == event,
                    "round-trip failed: \(line)")
        }
    }

    @Test("仕様§8の例をパースする")
    func specExamples() throws {
        let line = #"{"type":"pon","actor":"toimen","target":"self","pai":"1z","consumed":["1z","1z"]}"#
        let event = try EventCoding.event(fromLine: line, format: .paikei)
        #expect(event == .pon(actor: .toimen, target: .myself,
                              tile: try Tile.parse("1z"),
                              consumed: try Tile.parseHand("11z")))
    }

    @Test("不正な行は型付きエラー")
    func errors() throws {
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
struct MjaiDialectTests {
    @Test("MJAI牌表記の相互変換")
    func tileConversion() throws {
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
    func seatMapping() throws {
        let format = StreamFormat.mjai(selfActor: 2)
        let tsumo = try EventCoding.event(
            fromLine: #"{"type":"tsumo","actor":2,"pai":"W"}"#, format: format)
        #expect(tsumo == .tsumo(actor: .myself, tile: try Tile.parse("3z")))

        let pon = try EventCoding.event(
            fromLine: #"{"type":"pon","actor":3,"target":0,"pai":"5pr","consumed":["5p","5p"]}"#,
            format: format)
        #expect(pon == .pon(actor: .shimocha, target: .toimen,
                            tile: Tile(suit: .pin, rank: 5, isRed: true)!,
                            consumed: try Tile.parseHand("55p")))
    }
}

@Suite("ストリーム: ドキュメント (§8)")
struct PaikeiDocumentTests {
    let snapshotText = """
        wall: 42

        [self] seat=E
        hand: 123m456m789p55s11z
        score: 25000
        """

    @Test("[stream] が無ければイベントは空")
    func noStream() throws {
        let doc = try PaikeiDocument.parse(snapshotText)
        #expect(doc.events.isEmpty)
        #expect(try doc.state() == doc.snapshot)
    }

    @Test("パース → 適用。コメントと空行は無視")
    func parseAndApply() throws {
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
        #expect(t1.players[.myself]?.draw == Tile(suit: .sou, rank: 6))
        let final = try doc.state()  // 既定は末尾（§8.3）
        #expect(final.players[.myself]?.river.count == 1)
        #expect(final.wall == 41)
    }

    @Test("範囲外のステップは型付きエラー")
    func stepOutOfRange() throws {
        let doc = try PaikeiDocument.parse(snapshotText)
        #expect(throws: PaikeiDocument.StepOutOfRange(requested: 5, available: 0)) {
            _ = try doc.state(at: 5)
        }
    }

    @Test("ドキュメント全体がラウンドトリップする")
    func roundTrip() throws {
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

    @Test("mjai は self_actor が必須、未知の format はエラー")
    func headerValidation() throws {
        #expect(throws: StreamParseError.missingSelfActor) {
            _ = try PaikeiDocument.parse(snapshotText + "\n[stream] format=mjai\n")
        }
        #expect(throws: StreamParseError.unknownFormat("tenhou")) {
            _ = try PaikeiDocument.parse(snapshotText + "\n[stream] format=tenhou\n")
        }
    }

    @Test("from-mjai フィクスチャ: mjai ストリームを再生できる")
    func fromMjaiFixture() throws {
        let doc = try PaikeiDocument.parse(loadFixture("from-mjai"))
        #expect(!doc.events.isEmpty)

        let final = try doc.state()
        // 最初のイベントで claim_tile(1m) がスルーされ、対面の河に確定する。
        #expect(final.claim == nil)
        #expect(final.players[.toimen]?.river.last?.tile == Tile(suit: .man, rank: 1))
    }
}
