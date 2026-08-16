# LoopTogether

**Run smarter with friends.** Track routes, hit daily goals, and compete on a weekly leaderboard — all from your wrist and phone.

[![Download on the App Store](https://img.shields.io/badge/Download_on_the-App_Store-0D96F6?style=for-the-badge&logo=apple&logoColor=white)](https://apps.apple.com/us/app/looptogether/id6763824616)

> 📱 **LoopTogether is live on the App Store — [download it here](https://apps.apple.com/us/app/looptogether/id6763824616).** Free · Health & Fitness · iPhone + Apple Watch

---

LoopTogether is a running and walking app built for people who stay motivated with friends. Start a free run or generate a loop route that brings you back to where you started, keep a full history of every run with maps and splits, and see how you stack up against friends on daily and weekly leaderboards. Whether you're building a habit or chasing a goal, LoopTogether keeps you moving.

## Features

- 🗺️ **Route tracking** — GPS tracking with turn-by-turn voice guidance
- 🧭 **Custom route builder** — drop waypoints to design your own loops
- 📊 **Real-time stats** — distance, pace, calories, and duration as you run
- 👟 **Friend competitions** — daily and weekly leaderboards with your friends
- 🎯 **Daily challenges** — 1-mile runs, 10,000 steps, 5K completion, 20-minute activity
- 💍 **Monthly goals** — track your distance goal with a visual progress ring
- 📅 **Activity calendar** — see your daily mileage at a glance
- ⌚ **Apple Watch app** — glanceable stats and run control from your wrist
- 🏝️ **Live Activities & widgets** — follow an in-progress run from the Lock Screen and Dynamic Island

## Tech Stack

- **Swift** & **SwiftUI**
- **watchOS** companion app (Apple Watch)
- **WidgetKit** — Live Activities + home screen widgets
- **Firebase / Firestore** — authentication, friends, and synced run data
- **CoreLocation** & **MapKit** — GPS tracking, route generation, and maps
- **HealthKit** — step counts and workout data
- **WatchConnectivity** — phone ↔ watch session sync

## Project Structure

| Path | What's inside |
| --- | --- |
| `nameRunner/` | Main iPhone app — views, managers, Firestore services, run models |
| `LoopTogetherWatch Watch App/` | Apple Watch companion app |
| `LoopTogetherWidget/` | Live Activities and home screen widgets |
| `LoopTogetherUITests/` | XCUITest suite (Page Object pattern) |

## Building

This is an Xcode project. To build locally:

1. Clone the repo and open `nameRunner.xcodeproj` in Xcode.
2. Swift Package Manager resolves dependencies (Firebase) automatically.
3. Add your own `GoogleService-Info.plist` from a Firebase project to run the backend features.
4. Select a device or simulator and run.

## Author

**Khawar Khan** — [GitHub](https://github.com/khawarrr)
