import Foundation
import CoreGraphics

@main
struct TestPersistence {
    static func main() throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let profilesUrl = appSupport.appendingPathComponent("MouseControl/profiles.json")

        print("Checking profiles.json existence: \(fileManager.fileExists(atPath: profilesUrl.path))")
        let data = try Data(contentsOf: profilesUrl)
        let decoded = try JSONDecoder().decode([DeviceProfile].self, from: data)

        print("Decoded profiles count: \(decoded.count)")
        for p in decoded {
            print("Profile: \(p.name), Default: \(p.isDefault), Assignments: \(p.assignments.count)")
            for (btn, action) in p.assignments {
                print("  Button \(btn) -> \(action.displayName) (Type: \(action.type), KeyCode: \(action.keyCode))")
            }
        }

        assert(decoded.count >= 2, "Must have at least 2 profiles")
        assert(decoded[0].assignments[4]?.type == .wisprFlowPTT, "Button 4 must be Wispr Flow PTT")
        assert(decoded[0].assignments[3]?.type == .undo, "Button 3 must be Undo")
        print("ALL PERSISTENCE ASSERTIONS PASSED!")
    }
}
