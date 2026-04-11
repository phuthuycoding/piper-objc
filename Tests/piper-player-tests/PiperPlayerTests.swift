#if canImport(AVFoundation)
import XCTest
@testable import piper_player

final class PiperPlayerTests: XCTestCase {
    func testInitWithInvalidModel() {
        XCTAssertThrowsError(
            try PiperPlayer(params: .init(
                modelPath: "/nonexistent/model.onnx",
                configPath: "/nonexistent/config.json"
            ))
        ) { error in
            XCTAssertTrue(error is PiperPlayer.PlayerError)
        }
    }

    func testParamsDefaultEspeakData() {
        let params = PiperPlayer.Params(
            modelPath: "/path/to/model",
            configPath: "/path/to/config"
        )
        XCTAssertEqual(params.espeakNGData, "")
    }

    func testParamsCustomEspeakData() {
        let params = PiperPlayer.Params(
            modelPath: "/path/to/model",
            configPath: "/path/to/config",
            espeakNGData: "/custom/espeak"
        )
        XCTAssertEqual(params.espeakNGData, "/custom/espeak")
    }

    func testPlayerErrorCases() {
        let error1 = PiperPlayer.PlayerError.noPiperBackend
        let error2 = PiperPlayer.PlayerError.engineNotReady
        XCTAssertNotNil(error1.localizedDescription)
        XCTAssertNotNil(error2.localizedDescription)
    }
}
#endif
