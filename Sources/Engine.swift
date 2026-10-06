import Foundation

/// Finglish -> Persian. Local rules give instant guesses; Google Input Tools refines them online.
final class Engine {
    static let shared = Engine()

    let supportDir: URL
    private var learned: [String: [String: Int]] = [:]   // what the user picked for a given Latin text
    private var cache: [String: [String]] = [:]          // Google answers already seen
    private let learnedURL: URL
    private let cacheURL: URL

    private static let digraphs: [String: [String]] = [
        "kh": ["خ"], "sh": ["ش"], "ch": ["چ"], "zh": ["ژ"], "gh": ["ق", "غ"],
    ]
    private static let consonants: [Character: [String]] = [
        "b": ["ب"], "p": ["پ"], "t": ["ت", "ط"], "s": ["س", "ص", "ث"], "j": ["ج"],
        "h": ["ه", "ح"], "d": ["د"], "z": ["ز", "ض", "ذ", "ظ"], "r": ["ر"], "f": ["ف"],
        "k": ["ک"], "g": ["گ"], "l": ["ل"], "m": ["م"], "n": ["ن"], "v": ["و"],
        "y": ["ی"], "q": ["ق"], "x": ["خ"], "w": ["و"], "c": ["ک", "س"], "'": ["ع", "ئ", "ء"],
    ]

    init() {
        supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FinglishIME")
        learnedURL = supportDir.appendingPathComponent("learned.json")
        cacheURL = supportDir.appendingPathComponent("cache.json")
        learned = Engine.load(learnedURL) ?? [:]
        cache = Engine.load(cacheURL) ?? [:]
    }

    private static func load<T: Decodable>(_ url: URL) -> T? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    private func save<T: Encodable>(_ value: T, _ url: URL) {
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: url) }
    }

    // MARK: public

    /// Instant candidates: learned picks, cached Google answers, then rule-based spellings; Latin text last.
    func localCandidates(for input: String) -> [String] {
        let key = input.lowercased()
        var out: [String] = []
        func add(_ t: String) { if !t.isEmpty, !out.contains(t), out.count < 9 { out.append(t) } }
        for (t, _) in (learned[key] ?? [:]).sorted(by: { $0.value > $1.value }) { add(t) }
        (cache[key] ?? []).forEach(add)
        generate(Array(key), limit: 12).forEach { add($0) }
        return out + [input]
    }

    /// Merge Google's answer (most probable first) with what we already show.
    func merged(google: [String], for input: String) -> [String] {
        let key = input.lowercased()
        cache[key] = google
        if cache.count > 20000 { cache = [key: google] }
        save(cache, cacheURL)
        var out: [String] = []
        func add(_ t: String) { if !t.isEmpty, !out.contains(t), out.count < 9 { out.append(t) } }
        for (t, _) in (learned[key] ?? [:]).sorted(by: { $0.value > $1.value }) { add(t) }
        google.forEach(add)
        generate(Array(key), limit: 12).forEach { add($0) }
        return out + [input]
    }

    func learn(_ input: String, _ word: String) {
        let key = input.lowercased()
        guard key != word else { return }
        learned[key, default: [:]][word, default: 0] += 1
        save(learned, learnedURL)
    }

    // MARK: Google Input Tools (online)

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 3
        return URLSession(configuration: cfg, delegate: NoRedirect(), delegateQueue: nil)
    }()
    private var task: URLSessionDataTask?

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse,
                        newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }

    /// Only ever talks to https://inputtools.google.com, only sends the word being typed.
    func fetchGoogle(_ input: String, completion: @escaping ([String]) -> Void) {
        task?.cancel()
        var c = URLComponents()
        c.scheme = "https"; c.host = "inputtools.google.com"; c.path = "/request"
        c.queryItems = [.init(name: "text", value: input), .init(name: "itc", value: "fa-t-i0-und"),
                        .init(name: "num", value: "8"), .init(name: "ie", value: "utf-8"),
                        .init(name: "oe", value: "utf-8"), .init(name: "app", value: "finglish-ime")]
        guard let url = c.url, url.host == "inputtools.google.com" else { return }
        task = session.dataTask(with: url) { data, resp, _ in
            guard let data, (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.first as? String == "SUCCESS",
                  let results = json.dropFirst().first as? [[Any]],
                  let words = results.first?.dropFirst().first as? [String] else { return }
            DispatchQueue.main.async { completion(words) }
        }
        task?.resume()
    }

    func cancelFetch() { task?.cancel() }

    // MARK: rules

    /// All ways the Latin text at position i can be written in Persian: (letters, chars consumed, penalty).
    private func expansions(_ s: [Character], _ i: Int) -> [(String, Int, Double)] {
        var r: [(String, Int, Double)] = []
        let c = s[i]
        let start = i == 0, end = i == s.count - 1
        let next: Character? = i + 1 < s.count ? s[i + 1] : nil
        var split = 0.0

        if let nx = next {
            let two = String([c, nx])
            if let opts = Engine.digraphs[two] {
                for (k, o) in opts.enumerated() {
                    r.append((o, 2, Double(k) * 0.8))
                    if two == "kh", i + 2 < s.count, s[i + 2] == "a" { r.append((o + "و", 2, 0.5)) }   // خوا
                }
                split = 2
            }
            switch two {
            case "aa": if start { r.append(("آ", 2, 0)); r.append(("ا", 2, 0.8)) } else { r.append(("ا", 2, 0)) }
            case "ee", "ii": r.append(("ی", 2, 0))
            case "oo", "ou", "uu": r.append(("و", 2, 0))
            default: break
            }
        }
        if let opts = Engine.consonants[c] {
            for (k, o) in opts.enumerated() {
                let p = split + Double(k) * 0.8
                r.append((o, 1, p))
                if next == c { r.append((o, 2, p + 0.3)) }
            }
            return r
        }
        func opt(_ l: String, _ cost: Double) { r.append((l, 1, split + cost)) }
        func skip(_ cost: Double) { r.append(("", 1, split + cost)) }
        switch c {
        case "a":
            if start && end { opt("آ", 0); opt("ا", 0.2) }
            else if start { opt("آ", 0); opt("ا", 0.8) }
            else if end { opt("ا", 0); opt("ه", 1.0) }
            else { opt("ا", 0); skip(0.6) }
        case "e":
            if start { opt("ا", 0) } else if end { opt("ه", 0); skip(1.0); opt("ی", 1.5) } else { skip(0); opt("ا", 1.5) }
        case "i":
            if start { opt("ای", 0); opt("ا", 0.8) } else if end { opt("ی", 0); skip(2) } else { opt("ی", 0); skip(0.8) }
        case "o":
            if start && end { opt("و", 0) }
            else if start { opt("ا", 0); opt("او", 1.0) }
            else if end { opt("و", 0); skip(1.0) }
            else { skip(0.2); opt("و", 0.3) }
        case "u":
            if start { opt("او", 0); opt("ا", 1) } else if end { opt("و", 0) } else { opt("و", 0); skip(1) }
        default: break
        }
        return r
    }

    /// Beam search over the rules: the best `limit` Persian spellings.
    private func generate(_ s: [Character], limit: Int) -> [String] {
        guard !s.isEmpty else { return [] }
        var beams = [[(text: String, pen: Double)]](repeating: [], count: s.count + 1)
        beams[0] = [("", 0)]
        for i in 0..<s.count {
            if beams[i].count > 40 {
                var seen = Set<String>()
                beams[i] = beams[i].sorted { $0.pen < $1.pen }.filter { seen.insert($0.text).inserted }.prefix(40).map { $0 }
            }
            for b in beams[i] {
                for (letters, len, cost) in expansions(s, i) { beams[i + len].append((b.text + letters, b.pen + cost)) }
            }
        }
        var seen = Set<String>()
        return beams[s.count].sorted { $0.pen < $1.pen }.filter { !$0.text.isEmpty && seen.insert($0.text).inserted }
            .prefix(limit).map { $0.text }
    }
}
