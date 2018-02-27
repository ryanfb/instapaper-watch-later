# instapaper-watch-later

A script to move YouTube videos in your Instapaper feed to a YouTube "Watch Later" style playlist.

There's no YouTube API access to the actual "Watch Later" playlist, so by default this script will find/create a playlist named "Instapaper" for these videos.

## Usage

You'll need to [request your own Instapaper OAuth consumer tokens](https://www.instapaper.com/main/request_oauth_consumer_token), then copy `secrets.yml.example` to `.secrets.yml`, editing in the tokens you receive. On first run, the script will prompt you for an interactive user login, and persist the OAuth user credentials it receives.

You'll also need to generate a `client_secrets.json` file with credentials for YouTube Data API permissions in the [Google Developers Console](https://console.developers.google.com/). On first run you'll also be prompted for a Google/YouTube username to request/persist OAuth user credentials for YouTube.

I suggest running this interactively the first time then putting this script in a `cron` job.
