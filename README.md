# Scyphomote

Scyphomote is a dedicated remote control for Jellyfin, built with Flutter.

## Features

* **Multi-server** and **multi-user** management.
* **Playback controls**: Play, pause, stop, seek, volume.
* **Advanced controls**: Fast forward, rewind, and track skipping.
* **Media Library**: Browse and play movies, shows, and music directly from the app.
* **Resume Watching**: Resume playback on supported devices.
* **Segment Skipping**: Skip intros, outros, and other segments.
* **Communication**: Send messages to active sessions.
* **Stream Selection**: Change audio tracks and subtitles on the fly.
* **Remote Navigation**: Full directional remote for controlling any Jellyfin client interface that supports it.
* **Now Playing**: Metadata, high-quality artwork, and synchronized **lyrics** for music.
* **Trickplay support**: Visual frame previews while seeking (supports Jellyfin's trickplay/bif files).
* **Cast & Crew**: View cast and crew members.
* **Playback transparency**: View playback method (Direct Play vs. Transcoding) with detailed transcode reasons and quality metrics.
* **Detailed session information** (capabilities, supported commands, media types).
* Material 3 interface with light/dark theme support.
* *And more!*

## Download

### Android

<a href='https://play.google.com/store/apps/details?id=com.eiffelbeef.scyphomote&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'>
  <img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' width="200"/>
</a>

### Linux, Windows, MacOS, iOS (sideloading)

<a href='https://github.com/eiffelbeef/scyphomote/releases'>
  <img alt='Get it on GitHub' src='https://img.shields.io/badge/GitHub-Release-blue?style=for-the-badge&logo=github'/>
</a>

### Docker

You can also run the application using Docker:

```bash
docker-compose up -d
```

This will pull the latest image from GHCR and serve it at `http://localhost:6262`.

## Screenshots

<div style="display: flex; overflow-x: auto; gap: 10px; padding-bottom: 10px;">
  <img src="screenshots/player_dark.png" height="500" alt="Player Dark"/>
  <img src="screenshots/player_light.png" height="500" alt="Player Light"/>
  <img src="screenshots/sessions_dark.png" height="500" alt="Sessions"/>
  <img src="screenshots/remote.png" height="500" alt="Remote"/>
  <img src="screenshots/library.png" height="500" alt="Library"/>
</div>

## Building

Requires Flutter SDK 3.10+.

```bash
# Get dependencies
flutter pub get

# Run on available device
flutter run
```

## License

This project is licensed under the [GNU AGPLv3](LICENSE).
