<h1 align="center">
  <br>
    <img src="Assets/AppIcon.png" width="150" alt="scrobble.up Logo" />
  </br>
    scrobble.up
    <h3 align="center"> 
      For the music
    </h3>
    <div align="center">
      <img alt="GitHub License" src="https://img.shields.io/github/license/netliam/scrobble.up">
      <img alt="GitHub Release" src="https://img.shields.io/github/v/release/netliam/scrobble.up">
    </div>
  </br>
</h1>

---

**scrobble.up** is a lightweight music scrobbler for macOS that lives in your menu bar. Track your listening history across Last.fm and ListenBrainz, discover new music through Last.fm's similar tracks suggestion, and keep your favorite tracks synced across Apple Music. 

### Features
- **Lightweight & Native** - Uses ~80MB of memory, 100% Swift
- **Universal Scrobbling** - Track listens to Last.fm and ListenBrainz simultaneously
- **Wide Player Support** - Works with Apple Music, Spotify, and many other music players
- **Music Discovery** - Get similar artists and tracks from Last.fm right in you menu bar
- **Love Syncing** - Keep your favorite tracks synchronized across Apple Music, Last.fm, and ListenBrainz
- **Rich Artwork Display** - Optionally display album art in your dock and desktop widget
- **Desktop Widget** - Elegant widget shows what's currently playing
- **Global Shortcuts** - Quick actions to bring your player forward or love tracks without switching apps
- **Free & Open Source** - No subscriptions, no paid licenses, just GPLv3 forever



### Screenshots

<div align="center">
<img src="Assets/Menu_Screenshot.png" width="300" alt="Menu Screenshot" >
<img src="Assets/Desktop_Widget.png" width="200" alt="Desktop Widget" >
</div>
  
## Installation
**System Requirements:**  
- macOS **14 Sonoma** or later 

### Manual Installation (Currently the only option)
<a href="https://github.com/netliam/scrobble.up/releases/latest/download/scrobble.up.dmg" target="_self"><img width="200" src="Assets/Download_for_MacOS.png" alt="Download for macOS" /></a>

---

## Building the app
### **Prerequisites**  
- **macOS 14 Sonoma** or later
- **Xcode 16** or later
- **last.fm API key & secret**
  - This can be obtained at: [Last.fm Create API Account](https://www.last.fm/api/account/create)
    - You'll need to provide a description of the application
      > A macOS menu bar application that scrobbles music via the system player to Last.fm.
### **Setup**
1. Clone the repository
2. Rename **Secrets.xcconfig.example** to **Secrets.xcconfig**
3. Add the API key & secret you created to **Secrets.xcconfig**

---

## Credits & Acknowledgments

- ### [**NowPlaying**](https://github.com/diego-castilho/NowPlaying) - The project that scrobble.up is based on.
- ### [**boring.notch**](https://github.com/TheBoredTeam/boring.notch) - Much of the functionality for the like syncing feature comes from boring.notch. The README for scrobble.up is also based on boring.notch's.
- ### [**LastFM.swift**](https://github.com/duhnnie/LastFM.swift) - Amazing library used for communicating with last.fm.
