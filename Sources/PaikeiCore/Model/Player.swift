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
