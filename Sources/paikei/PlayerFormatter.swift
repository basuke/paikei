import PaikeiCore

extension RyukyokuReason {
    /// 人間向けの流局理由。語彙外の値は生の文字列をそのまま見せる。
    var displayName: String {
        switch self {
        case .荒牌平局: "荒牌平局"
        case .九種九牌: "九種九牌"
        case .四風連打: "四風連打"
        case .四家立直: "四家立直"
        case .四開槓: "四開槓"
        case .三家和: "三家和"
        case let .その他(text): text
        }
    }
}

extension Player {
    /// 人間向けの位置名（プレゼンテーション層）。
    ///
    /// case 名と同じ文字列だが、表示は表示として明示的に持つ。
    /// 内部名を変えたときに出力が黙って変わらないようにするため。
    var displayName: String {
        switch self {
        case .自分: "自分"
        case .下家: "下家"
        case .対面: "対面"
        case .上家: "上家"
        }
    }
}
