.PHONY: android_publish_local android_verify flutter_golden_test flutter_verify push_main push_main_test swift_format_lint swift_ios_build swift_ios_test swift_test swift_verify verify

verify: flutter_verify swift_verify android_verify

push_main:
	bash scripts/push_main.sh

push_main_test:
	bash scripts/push_main_test.sh

android_verify:
	cd android && ./gradlew :chat-core:test :chat-ui-compose:lintDebug :chat-ui-compose:testDebugUnitTest :chat-ui-compose:compileDebugAndroidTestKotlin :chat-core:generatePomFileForMavenPublication :chat-ui-compose:generatePomFileForReleasePublication

android_publish_local:
	cd android && ./gradlew publishAllPublicationsToLocalBuildRepository

flutter_verify:
	flutter pub get
	flutter analyze
	flutter test --exclude-tags=golden

flutter_golden_test:
	flutter test --tags=golden

swift_verify: swift_format_lint swift_test swift_ios_build swift_ios_test

swift_format_lint:
	xcrun swift-format lint --recursive --strict Package.swift Sources Tests

swift_test:
	swift test --no-parallel --skip ChatTimelineScrollViewTests
	# AppKitのホスティング状態をテスト間で共有するとrunner上でクラッシュするため、各テストを別プロセスで実行する。
	swift test --skip-build --filter ChatTimelineScrollViewTests.positionsLatestAtBottom
	swift test --skip-build --filter ChatTimelineScrollViewTests.positionsSpecifiedItemAtCenter
	swift test --skip-build --filter ChatTimelineScrollViewTests.positionsLatestWhenHiddenTimelineBecomesReady
	swift test --skip-build --filter ChatTimelineScrollViewTests.positionsSpecifiedItemWhenHiddenTimelineBecomesReady
	swift test --skip-build --filter ChatTimelineScrollViewTests.preservesPositionWhenHistoryIsPrepended

swift_ios_build:
	xcodebuild -scheme AltiveChat-Package -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/altive-chat-derived CODE_SIGNING_ALLOWED=NO build

swift_ios_test:
	xcodebuild -scheme AltiveChat-Package -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/altive-chat-ios-test-derived CODE_SIGNING_ALLOWED=NO test \
		-only-testing:AltiveChatUITests/ChatPasteAwareTextFieldIOSTests \
		-only-testing:AltiveChatUITests/ChatTimelineIOSScrollViewTests
