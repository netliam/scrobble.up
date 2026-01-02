<h1 align="center">
  <br>
    <img src="Assets/AppIcon.png" width="150" alt="scrobble.up Logo" />
  <br>
  scrobble.up
  <br>
</h1>

**scrobble.up** is a lightweight Free and Open Source scrobbler for Apple Music and Spotify that lives in your menu bar.

### Features
- Scrobble to support for last.fm & ListenBrainz
- Recently played and scrobbled logs
- Similar artists and track suggestions from last.fm
- Like syncing between Apple Music and last.fm
- Displaying track artwork in the dock icon

## Installation
**System Requirements:**  
- macOS **14 Sonoma** or later  

---

### Manual Installation (Currently the only option)
<a href="https://github.com/netliam/scrobble.up/releases/download/latest/ScrobbleUp.dmg" target="_self"><img width="200" src="Assets/Download_for_MacOS.png" alt="Download for macOS" /></a>

### Using scrobble.up
- Launch the app
- Click "Connect to Last.fm"
- Authorize scrobble.up on the Last.fm page
- Click "I've authorized scrobble.up — Complete login"
- And you're done and ready to start scrobbling

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
