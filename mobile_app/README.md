# arXiv Trend Advisor – Mobile App

This is the **mobile app** component. It is a Flutter app that calls the backend API (advisor endpoint) so you can get domain classification, growth trend, and suggested keywords from your phone or emulator.

## Prerequisites

- Flutter SDK installed ([flutter.dev](https://flutter.dev))
- Backend running (or use the default production API; the app is configured to use it out of the box)

## How to run

Commands below assume you are in the **project root** (the folder that contains `backend/`, `web_app/`, `mobile_app/`, and `research_pipeline/`). To enter the mobile app folder from the project root: `cd mobile_app`.

1. From the project root: `cd mobile_app`
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run` (connect a device or start an emulator)

## API URL

By default the app uses the production API. To use a local backend, change the base URL in `lib/services/api_service.dart` and rebuild the app.

## Full project

For the full project (research pipeline, backend, web app), see the [root README](../README.md).
