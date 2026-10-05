// Responsibility: privacy-filtered pasteboard polling. Connects AppKit to ClipboardStore.
// Development status: complete.
import AppKit
import ClipNestCore

final class ClipboardMonitor {
    let board: NSPasteboard
    let store: ClipboardStore
    var onChange: (() -> Void)?
    var paused = false { didSet { count = board.changeCount } }
    private var count: Int
    private var timer: Timer?
    init(store: ClipboardStore, board: NSPasteboard) {
        self.store = store; self.board = board; count = board.changeCount
    }
    func start() {
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func poll() {
        guard count != board.changeCount else { return }
        count = board.changeCount
        guard !paused else { return }
        let types = (board.pasteboardItems ?? []).flatMap { $0.types.map(\.rawValue) }
        guard !ClipboardPolicy.isSensitive(types), let text = board.string(forType: .string), ClipboardPolicy.accepts(text) else { return }
        store.ingest(text); onChange?()
    }
     @discardableResult func copy(_ text: String) -> Bool {
        board.clearContents(); let succeeded = board.setString(text, forType: .string)
        count = board.changeCount // Suppress exactly our own write; future external repeats still count.
        return succeeded
    }
}
