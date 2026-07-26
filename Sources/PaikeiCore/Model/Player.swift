/// カメラ相対のプレイヤー位置（仕様§3.2）。
///
/// 席風（東家/南家…）ではなく「自分から見た物理的な位置」を主キーにする。
/// 正規化出力・列挙の順序は self → shimocha → toimen → kamicha（宣言順）。
public enum Player: String, Sendable, CaseIterable {
    case myself = "self"      // 自分（`self` は予約語のため myself）
    case shimocha = "shimocha" // 下家（自分の右）
    case toimen = "toimen"     // 対面
    case kamicha = "kamicha"   // 上家（自分の左）
}

extension Player {
    /// このプレイヤーから見て `direction` の位置にいるプレイヤー。
    ///
    /// 例: `.shimocha.seated(.kamicha) == .myself`（下家から見た上家は自分）。
    /// 副露の「誰から鳴いたか」を絶対位置に解決するのに使う（仕様§5）。
    public func seated(_ direction: CallDirection) -> Player {
        let offset: Int
        switch direction {
        case .shimocha: offset = 1
        case .toimen: offset = 2
        case .kamicha: offset = 3
        }
        let all = Player.allCases  // 宣言順 = 手番順（self → shimocha → toimen → kamicha）
        let index = all.firstIndex(of: self)!
        return all[(index + offset) % all.count]
    }
}
