import FastFlowPlugins
import Foundation

@main
enum FastFlowBenchMain {
    static func main() async {
        print("FastFlowBench — ASR cold-start harness")
        print("role=\(PluginCapabilityEnforcer.roleFromEnvironment().rawValue) escape=\(PluginCapabilityEnforcer.escapeFromEnvironment())")
        do {
            let results = try await ASRColdStartBenchmark.runDefaultSuite()
            ASRColdStartBenchmark.printReport(results)
            if let enc = try? JSONEncoder().encode(results),
               let json = String(data: enc, encoding: .utf8) {
                print("--- json ---")
                print(json)
            }
        } catch {
            fputs("FastFlowBench failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
