/// カメラ相対のプレイヤー位置（仕様§3.2）。
///
/// 席風（東家/南家…）ではなく「自分から見た物理的な位置」を主キーにする。
/// 正規化出力・列挙の順序は 自分 → 下家 → 対面 → 上家（宣言順 = 手番順）。
///
/// rawValue は `.paikei` の表記トークン（仕様§3.2）なので ASCII 固定。
public enum Player: String, Sendable, CaseIterable {
    case 自分 = "self"
    /// 自分の右。
    case 下家 = "shimocha"
    case 対面 = "toimen"
    /// 自分の左。
    case 上家 = "kamicha"
}

extension Player {
    /// 自分を 0 とした手番順の位置（self=0 → shimocha=1 → toimen=2 → kamicha=3）。
    ///
    /// MJAIの絶対座席との相互変換（仕様§8.2）に使う。
    public var order: Int {
        Player.allCases.firstIndex(of: self)!
    }

    /// このプレイヤーから見て `direction` の位置にいるプレイヤー。
    ///
    /// 例: `.下家.seated(.上家) == .自分`（下家から見た上家は自分）。
    /// 副露の「誰から鳴いたか」を絶対位置に解決するのに使う（仕様§5）。
    public func seated(_ direction: CallDirection) -> Player {
        let offset: Int
        switch direction {
        case .下家: offset = 1
        case .対面: offset = 2
        case .上家: offset = 3
        }
        let all = Player.allCases  // 宣言順 = 手番順（self → shimocha → toimen → kamicha）
        return all[(order + offset) % all.count]
    }

    /// `seated` の逆引き: このプレイヤーから見た `other` の方向。自分自身なら nil。
    ///
    /// イベントから副露を組み立てるとき（`pon` の `target` → 方向）に使う。
    public func direction(to other: Player) -> CallDirection? {
        for direction in [CallDirection.下家, .対面, .上家]
            where seated(direction) == other {
            return direction
        }
        return nil
    }
}
