extension StringProtocol {
    /// 前後の空白（半角/全角スペース・タブ等）を取り除いた部分文字列。
    ///
    /// Foundation の `trimmingCharacters(in:)` を避けてコアの依存を最小化するための実装。
    func trimmingWhitespace() -> SubSequence {
        var start = startIndex
        var end = endIndex
        while start < end, self[start].isWhitespace {
            start = index(after: start)
        }
        while start < end {
            let prev = index(before: end)
            guard self[prev].isWhitespace else { break }
            end = prev
        }
        return self[start..<end]
    }
}
