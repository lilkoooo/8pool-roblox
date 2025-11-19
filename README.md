# 🎱 Premium 8-Ball Billiards for Roblox

Modern, professional billiards minigame with realistic physics and beautiful UI.

## ✨ Features

- 🎮 **2-Player Matchmaking** - Queue system with automatic matching
- 🎨 **Modern Dark UI** - Sleek design with gradients and animations
- ⚙️ **Realistic Physics** - Smooth 60 FPS ball movement
- 🎯 **Intuitive Controls** - Click-and-drag shooting
- 🏆 **Win Detection** - Full 8-ball rules
- 🧪 **Solo Test Mode** - Play alone for testing

## 📦 Installation

1. Open Roblox Studio
2. Create new Baseplate
3. Copy `BilliardsServer.lua` to **ServerScriptService**
4. Copy `BilliardsClient.lua` to **StarterPlayer > StarterPlayerScripts**
5. Follow `SETUP_GUIDE.md` for UI creation
6. Create BilliardTable model in Workspace with ProximityPrompt
7. Test with **F5**!

## 🎮 How to Play

1. Walk to the billiard table
2. Press **E** to join queue
3. Wait for opponent (or play solo in test mode)
4. **Click and drag** the white cue ball to shoot
5. Drag further = more power
6. Pocket all your balls, then sink the 8-ball to win!

## 🔧 Configuration

**Enable Multiplayer:** In `src/BilliardsServer.lua`, line ~60, change:
```lua
if #matchQueue >= 1 then  -- Test mode (solo)
```
to:
```lua
if #matchQueue >= 2 then  -- Multiplayer mode
```

## 📂 File Structure

```
src/
├── BilliardsServer.lua    (ServerScriptService)
├── BilliardsClient.lua    (StarterPlayerScripts)
└── UI_GUIDE.md           (Detailed UI creation)
```

## 🛠️ Technologies

- Roblox Lua
- TweenService (smooth animations)
- RemoteEvents (client-server communication)
- Modern UI design principles
- Realistic physics simulation

## 📄 License

MIT License - Free to use and modify!

## 👤 Author

Created by **lilkoooo** with GitHub Copilot

---

**Enjoy the game! 🎱✨**