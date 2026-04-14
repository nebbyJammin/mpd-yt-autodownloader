# MPD Youtube Autodownloader Script

A simple script written in elixir that downloads your youtube playlists using yt-dlp. The script will handle any changes made to your youtube playlists, such as adding new songs and removing songs. This script is designed to be used in parallel with [MPD](https://www.github.com/musicplayerdaemon/mpd), but you could also use this script standalone.

> Currently if a video in the playlist is unavailable, the script will error out. Ensure your playlists don't have such videos.

## Description

An in-depth paragraph about your project and overview of use.

## Getting Started

### Dependencies

> Note: This script has only been tested on Linux, but should in theory work for Windows and Mac as well.

Ensure you have installed:
- Erlang & Elixir (recommended via [asdf](https://github.com/asdf-vm/asdf))
- [Yt-dlp](https://github.com/yt-dlp/yt-dlp) and its dependencies including [ffmpeg](https://github.com/ffmpeg/ffmpeg) most importantly

### Installing

Start by cloning the repo, ideally in some subdirectory of `/Music`.

```bash
git clone https://github.com/nebbyJammin/mpd-yt-autodownloader
```

Then create a `config.json` file at the root of the repository, and copy the contents from `config.json.example` into the newly created `config.json` file.

```json
{
  "cookies_from_browser": "firefox",
  "playlists_directory": "./Playlists/",
  "playlists": [
    "https://www.youtube.com/playlist?list=<INSERT_YOUR_PLAYLIST_HERE>",
    "https://www.youtube.com/playlist?list=<INSERT_YOUR_PLAYLIST_HERE>"
  ]
}
```

- `cookies_from_browser`: A flag that is passed onto yt-dlp. See `--cookies-from-browser` flag in [yt-dlp](https://github.com/yt-dlp/yt-dlp).
- `playlists_directory`: A relative or absolute file path that denotes the location of your `Playlists` directory which is used by MPD.
- `playlists`: A list of URLs for each youtube playlist you wish to keep updated. It is highly recommended to ensure these playlists have a visibility that is either "unlisted" or "public". It is possible to update a playlist that is "private", but that relies on the `cookies_from_browser` working as intended, which is not guaranteed due to cookie rotation.

Finally, ensure that your `playlists_directory` exists.

### Executing program

To run the script and fetch the playlists as written in your `config.json`, execute the following command: 
```
elixir ytautodownloader.exs
```

This may take a while, depending on how many videos/songs need to be fetched, as well as your download speeds.

## Help

This script/project is still very early on, so I'm working on improving command line tooling.

For now, create an issue if you have problems.

## Authors

Made by [me](https://github.com/nebbyJammin) :)

## License

This project is licensed under the [MIT] License - see the [LICENSE.md](license.md) file for details
