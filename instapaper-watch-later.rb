#!/usr/bin/env ruby

require 'yaml'
require 'instapaper'
require 'highline'
require 'pp'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'yt'
require 'json'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
GOOGLE_SCOPE = 'https://www.googleapis.com/auth/youtube'
GOOGLE_TOKENS = '.google_tokens.yml'
GOOGLE_CLIENT_SECRETS = 'client_secrets.json'
DEFAULT_PLAYLIST_TITLE = 'Instapaper'

unless File.exist?('.secrets.yml')
  $stderr.puts 'Create a .secrets.yml config file with your Instapaper API credentials'
  exit
end

config = YAML.load_file('.secrets.yml')
config[:playlist_title] ||= DEFAULT_PLAYLIST_TITLE
cli = HighLine.new
client = nil
update_config = false

if config.has_key?(:consumer_key) && config.has_key?(:consumer_secret)
  client = Instapaper::Client.new do |client|
    client.consumer_key = config[:consumer_key]
    client.consumer_secret = config[:consumer_secret]
  end
  unless (config.has_key?(:oauth_token) && config.has_key?(:oauth_token_secret))
    $stderr.puts "Setting OAuth tokens using Instapaper login"
    username = cli.ask("Instapaper Username: ")
    password = cli.ask("Instapaper Password: ") { |q| q.echo = "x" }
    token = client.access_token(username, password)
    config[:oauth_token] = token.oauth_token
    config[:oauth_token_secret] = token.oauth_token_secret
    update_config = true
  end
  client.oauth_token = config[:oauth_token]
  client.oauth_token_secret = config[:oauth_token_secret]
  client.verify_credentials

  if update_config
    File.open('.secrets.yml','w') do |f|
      f.write(config.to_yaml)
    end
    $stderr.puts "Config updated with OAuth tokens"
  end
else
  $stderr.puts "Instapaper API consumer key & secret not set, exiting!"
  exit
end

client_id = Google::Auth::ClientId.from_file(GOOGLE_CLIENT_SECRETS)
token_store = Google::Auth::Stores::FileTokenStore.new(
  :file => GOOGLE_TOKENS)
authorizer = Google::Auth::UserAuthorizer.new(client_id, GOOGLE_SCOPE, token_store)
user_id = nil
if File.exist?(GOOGLE_TOKENS)
  user_id = YAML.load_file(GOOGLE_TOKENS).keys.first
  $stderr.puts "Using YouTube account: #{user_id}"
else
  user_id = cli.ask("Google/YouTube Username:")
end
credentials = authorizer.get_credentials(user_id)
if credentials.nil?
  url = authorizer.get_authorization_url(base_url: OOB_URI )
  puts "Open #{url} in your browser and enter the resulting code:"
  code = gets
  credentials = authorizer.get_and_store_credentials_from_code(
    user_id: user_id, code: code, base_url: OOB_URI)
end
Yt.configuration.client_id = client_id.id
Yt.configuration.client_secret = client_id.secret
Yt.configuration.log_level = :debug
youtube_account = Yt::Account.new refresh_token: credentials.refresh_token
unless config.has_key?(:playlist_id)
  $stderr.puts "No existing playlist ID found in config, searching for an existing playlist with title: #{config[:playlist_title]}"
  youtube_account.playlists.each do |playlist|
    if playlist.title == config[:playlist_title]
      config[:playlist_id] = playlist.id
      $stderr.puts "Found existing playlist #{config[:playlist_id]} with title #{config[:playlist_title]}"
      break
    end
  end
  unless config.has_key?(:playlist_id)
    $stderr.puts "No existing YouTube playlist found, creating a playlist named: #{config[:playlist_title]}"
    created_playlist = youtube_account.create_playlist(title: config[:playlist_title], privacy_status: "private")
    config[:playlist_id] = created_playlist.id
  end
  File.open('.secrets.yml','w') do |f|
    f.write(config.to_yaml)
  end
  $stderr.puts "Config updated with YouTube Playlist ID: #{config[:playlist_id]}"
end

youtube_playlist = Yt::Playlist.new id: config[:playlist_id], auth: youtube_account

instapaper_bookmarks = client.bookmarks(:limit => config[:bookmarks_limit])
$stderr.puts "Checking #{instapaper_bookmarks.to_h[:bookmarks].length} Instapaper bookmarks"
instapaper_bookmarks.each do |bookmark|
  if (bookmark.url =~ /^https?:\/\/(www\.)?youtube\.com\//)
    begin
      $stderr.puts bookmark.url
      video_id = bookmark.url.split('=')[1]
      $stderr.puts "Adding YouTube video #{video_id} to playlist: #{youtube_playlist.title}"
      youtube_playlist.add_video(video_id)
      $stderr.puts "Deleting Instapaper bookmark: #{bookmark.url}"
      client.delete_bookmark(bookmark.bookmark_id)
      $stderr.puts
    rescue Yt::Errors::Forbidden => e
      $stderr.puts e.inspect
    end
  end
end
