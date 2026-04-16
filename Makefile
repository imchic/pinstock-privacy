format:
	dart format lib/

analyze: format
	flutter analyze

run: analyze
	flutter run --dart-define-from-file=env.json

ios: analyze
	flutter run --dart-define-from-file=env.json -d $(shell flutter devices | grep iPhone | awk '{print $$4}' | head -1)

android: analyze
	flutter run --dart-define-from-file=env.json -d $(shell flutter devices | grep android | awk '{print $$4}' | head -1)

release: analyze
	flutter run --dart-define-from-file=env.json --release

build-apk: analyze
	flutter build apk --dart-define-from-file=env.json --release

build-appbundle: analyze
	flutter build appbundle --dart-define-from-file=env.json --release

open-apk:
	open build/app/outputs/flutter-apk/

build-ios: analyze
	flutter build ios --dart-define-from-file=env.json --release
