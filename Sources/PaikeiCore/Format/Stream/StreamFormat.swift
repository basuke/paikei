/// `[stream]` セクションの方言（仕様§8.2）。
public enum StreamFormat: Sendable, Equatable {
    /// Paikeiネイティブ。牌はMPSZ、actorはカメラ相対名（`self` など）。
    case paikei
    /// MJAI生ログ。牌はMJAI表記（`E`〜`C`、`5mr`）、actorは絶対座席 0〜3。
    /// `selfActor` は `self_actor` 属性（必須）。
    case mjai(selfActor: Int)
}

/// ストリームのパースに関するエラー（仕様§8）。
public enum StreamParseError: Error, Equatable, Sendable {
    /// JSONとして読めない行。
    case 不正なJSON(String)
    /// 語彙にないイベント種別。
    case 未知のイベント種別(String)
    /// 必須フィールドが無い。
    case フィールド欠落(String, イベント種別: String)
    /// フィールドの値が不正。
    case 不正な値(フィールド: String, 値: String)
    /// `format=` の値が不明。
    case 未知のformat(String)
    /// `format=mjai` なのに `self_actor` が無い（仕様§8.2で必須）。
    case self_actor欠落
    /// `[stream]` ヘッダの属性が不正。
    case 不正なヘッダ(String)
}

extension StreamFormat {
    /// MJAIの絶対座席をカメラ相対の `Player` に解決する（仕様§8.2）。
    ///
    /// 座順は反時計回り: shimocha = (self+1)%4, toimen = (self+2)%4, kamicha = (self+3)%4。
    func player(fromSeat seat: Int) throws -> Player {
        guard case let .mjai(selfActor) = self else {
            throw StreamParseError.不正な値(フィールド: "actor", 値: String(seat))
        }
        guard (0...3).contains(seat) else {
            throw StreamParseError.不正な値(フィールド: "actor", 値: String(seat))
        }
        return Player.allCases[(seat - selfActor + 4) % 4]
    }

    /// `player(fromSeat:)` の逆。paikei方言には絶対座席が無いので nil。
    func seat(of player: Player) -> Int? {
        guard case let .mjai(selfActor) = self else { return nil }
        return (selfActor + player.order) % 4
    }
}
