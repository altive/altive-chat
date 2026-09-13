import Foundation
import Testing
import UniformTypeIdentifiers

@testable import AltiveChatUI

struct ChatImageInputConfigurationTests {
  @Test func defaultsToFourPickerImages() {
    let configuration = ChatImageInputConfiguration()

    #expect(configuration.maximumSelectionCount == 4)
  }

  @Test("カメラ以外の利用可能な画像取得元だけをメニューへまとめる")
  func groupsAvailableMenuSources() {
    let sources = chatImageMenuSources(
      from: [.camera, .photoLibrary, .file, .clipboard],
      canRequestImageFiles: true,
      canPasteImages: false
    )

    #expect(sources == [.photoLibrary, .file])
  }

  @Test("画像取得元メニューの順序を写真、ファイル、ペーストに固定する")
  func fixesImageSourceMenuOrder() {
    #expect(chatImageMenuSourceOrder == [.photoLibrary, .file, .clipboard])
  }

  @Test("有効な場合だけ画像providerを貼り付け対象にする")
  func filtersPastedImageProviders() {
    let imageProvider = NSItemProvider()
    imageProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.png.identifier,
      visibility: .all
    ) { completion in
      completion(Data(), nil)
      return nil
    }
    let textProvider = NSItemProvider(object: "本文" as NSString)

    #expect(
      chatImageProviders(
        from: [imageProvider, textProvider],
        isEnabled: true
      ).count == 1
    )
    #expect(
      chatImageProviders(
        from: [imageProvider, textProvider],
        isEnabled: false
      ).isEmpty
    )
  }
}
