Mix.install([
  {:exqlite, "~> 0.13"}
])

defmodule Ytautodownloader.Constants do
  @yt_autodownload_dir Path.join(__DIR__, "yt-autodownload")
  @downloads_dir Path.join(@yt_autodownload_dir, "downloads")

  def yt_autodownload_path, do: @yt_autodownload_dir
  def downloads_path, do: @downloads_dir
end

# TODO: How do we handle videos that are made unavailable?
defmodule Ytautodownloader do

  def main(_args \\ []) do
    init()

    Ytautodownloader.Ytdlp.update_playlist("https://youtube.com/playlist?list=PLKLMsHwPzDZG4pXDwB2M7LwZYq6Rvx1dh")
  end

  defp init() do
    # Ensure directories exist
    case File.mkdir_p(Ytautodownloader.Constants.downloads_path) do
      :ok -> :ok
      {:error, _}
        -> IO.puts(:stderr, "Could not open/create directories")
    end
  end
end

defmodule Ytautodownloader.Config do
  defstruct [
    cookies_from_browser: "firefox",
    playlists_directory: "./Playlists/",
    playlists: [],
  ]

  @type t() :: %__MODULE__{
    cookies_from_browser: String.t(),
    playlists: [String.t()],
  }

  @spec load_config() :: {:ok, t()} | {:error, atom()}
  def load_config() do
    config_path = Path.join(__DIR__, "config.json")

    case File.open(config_path) do
      {:ok, config_file} ->
        config_file |> IO.inspect()
      {:error, _reason} ->
        # File is missing, so create config
        _config_file = File.open(config_path, [:write])
    end
  end

end

defmodule Ytautodownloader.Ytdlp do
  @doc """
  Updates a playlist fully. Can partially fail, if for example the downloading succeeds, but the metadata cannot be fetched.
  """
  @spec update_playlist(String.t()) :: :ok | :error
  def update_playlist(url) do
    with  :ok <- download_playlist(url),
          :ok <- make_playlist_manifest(url)
    do
      :ok
    else
      :error -> :error
    end
  end

  @spec playlist_name(String.t()) :: {:ok, String.t()} | :error
  def playlist_name(url) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", "firefox", # TODO: Accept options
      "--skip-download",
      "--flat-playlist",
      "--print", "%(playlist_title)s",
      "--playlist-items", "1",
      url,
    ]) do
      {_, 1} -> :error
      {res, 0} -> {:ok, res |> String.trim_trailing()}
    end
  end

  @spec playlist_songs_ids(String.t()) :: {:ok, [String.t()]} | :error
  def playlist_songs_ids(url) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", "firefox",
      "--flat-playlist",
      "--print", "id",
      url,
    ]) do
      {_, 1} -> :error
      {res, 0} ->
        {
          :ok,
          res
          |> String.trim_trailing()
          |> String.split("\n")
        }
    end
  end

  @spec make_playlist_manifest(String.t()) :: :ok | :error
  def make_playlist_manifest(url) do
    # TODO: Make this configurable
    playlists_directory = Path.join(__DIR__, "Playlists")

    with  {:ok, p_name} <- playlist_name(url),
          {:ok, p_songs} <- playlist_songs_ids(url)
    do
      file_contents = p_songs
      |> Enum.map(
        fn id ->
          Path.join(Ytautodownloader.Constants.downloads_path, "#{id}.mp3")
        end
      )
      |> Enum.join("\n")

      case File.write(Path.join(playlists_directory, "#{p_name}.m3u"), file_contents, [:write]) do
        {:error, _} -> 
          IO.puts("PLAYLIST WRITE ERROR")
          :error
        :ok -> :ok
      end
    else
      _ -> :error
    end
  end

  @spec download_playlist(String.t()) :: :ok | :error
  def download_playlist(url) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", "firefox",
      "--embed-metadata",
      "--embed-thumbnail",
      "--convert-thumbnails", "jpg",
      "--audio-quality", "0",
      "-x",
      "--audio-format", "mp3",
      "-f", "ba",
      "--windows-filenames",
      "--download-archive", Path.join(Ytautodownloader.Constants.downloads_path(), "__ARCHIVE__.txt"),
      "-o", Path.join(Ytautodownloader.Constants.downloads_path(), "%(id)s.%(ext)s"),
      url,
    ],
    [
      into: IO.stream(:stdio, :line)
    ]) do
      {_, 1} -> :error
      {_, 0} -> :ok
    end
  end
end

Ytautodownloader.main(System.argv())
