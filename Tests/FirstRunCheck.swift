import Darwin
import Foundation

// swiftc -parse-as-library Sources/D4Mac/Rosetta.swift Sources/D4Mac/InstallerDownload.swift \
//   Tests/FirstRunCheck.swift -o /tmp/first-run-check && /tmp/first-run-check
@main
struct FirstRunCheck {
    static func main() async {
        var failures = 0
        func check(_ ok: Bool, _ name: String) {
            if !ok { failures += 1; fputs("FAIL \(name)\n", stderr) }
        }
        func accepted(_ status: Int, _ url: String?) -> Bool {
            (try? InstallerDownload.checkResponse(status: status, finalURL: url.flatMap(URL.init(string:)))) != nil
        }

        // Only Blizzard hosts, only HTTPS, only 200 — checked after redirects.
        check(accepted(200, "https://downloader.battle.net/download/installer/win/1.0.68/Battle.net-Setup.exe"), "Blizzard CDN accepted")
        check(accepted(200, "https://www.battle.net/download/getInstallerForGame"), "battle.net accepted")
        check(accepted(200, "https://dist.blizzard.com/x.exe"), "blizzard.com subdomain accepted")
        check(!accepted(200, "http://downloader.battle.net/Battle.net-Setup.exe"), "plain HTTP rejected")
        check(!accepted(200, "https://battle.net.evil.example/Battle.net-Setup.exe"), "look-alike host rejected")
        check(!accepted(200, "https://evilbattle.net/Battle.net-Setup.exe"), "suffix without dot rejected")
        check(!accepted(200, nil), "missing URL rejected")
        check(!accepted(404, "https://downloader.battle.net/x.exe"), "HTTP 404 rejected")

        let mz = Data([0x4D, 0x5A])
        check(InstallerDownload.looksLikeInstaller(header: mz, size: 4_700_880), "5 MB PE accepted")
        check(!InstallerDownload.looksLikeInstaller(header: Data("<!".utf8), size: 4_700_880), "HTML page rejected")
        check(!InstallerDownload.looksLikeInstaller(header: mz, size: 20_000), "tiny file rejected")
        check(!InstallerDownload.looksLikeInstaller(header: Data(), size: 0), "empty download rejected")

        check(Rosetta.interpret(status: 0, stderr: "") == .installed, "exit 0 → installed")
        check(Rosetta.interpret(status: 1, stderr: "0:183: execution error: User canceled. (-128)\n") == .cancelled, "-128 → cancelled")
        if case .failed(let m) = Rosetta.interpret(status: 1, stderr: "execution error: Install failed (1)\n") {
            check(m == "execution error: Install failed (1)", "failure message trimmed")
        } else {
            check(false, "other error → failed")
        }

        // The probe on this Mac, and on a binary with no x86_64 slice, which
        // fails exactly like a Mac without Rosetta ("Bad CPU type").
        let installed = await Rosetta.isInstalled()
        print("Rosetta installed on this Mac: \(installed)")
        let arm64Only = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
        if let arm64Only {
            check(await Rosetta.isInstalled(probe: arm64Only) == false, "probe without x86_64 slice → not installed")
        }

        // The safety net in WineProcess relies on Process.run() surfacing
        // EBADARCH as NSPOSIXErrorDomain; spawn a Mach-O for a CPU this Mac
        // can't run (PowerPC) to see it.
        let ppc = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-check-ppc")
        var header = Data()
        for v: UInt32 in [0xFEEDFACE, 18, 0, 2, 0, 0, 0] { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }
        FileManager.default.createFile(atPath: ppc.path, contents: header, attributes: [.posixPermissions: 0o755])
        let p = Process()
        p.executableURL = ppc
        do {
            try p.run()
            check(false, "PowerPC binary should not spawn")
        } catch {
            let ns = error as NSError
            check(ns.domain == NSPOSIXErrorDomain && ns.code == Int(EBADARCH),
                  "spawn failure is NSPOSIXErrorDomain/EBADARCH (got \(ns.domain) \(ns.code))")
        }

        print(failures == 0 ? "all checks passed" : "\(failures) check(s) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
