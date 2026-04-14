Mix.install([
  {:jason, "~> 1.4"}
])

defmodule Ytautodownloader.Constants do
  @yt_autodownload_dir Path.join(__DIR__, "yt-autodownload")
  @downloads_dir Path.join(@yt_autodownload_dir, "downloads")
  @config_path Path.join(__DIR__, "config.json")

  def yt_autodownload_path, do: @yt_autodownload_dir
  def downloads_path, do: @downloads_dir
  def config_path, do: @config_path
end

defmodule Ytautodownloader do

  def main(_args \\ []) do
    init()
    config = Ytautodownloader.Config.load_config!()
    
    config.playlists
    |> Enum.each(
      fn url ->
        Ytautodownloader.Ytdlp.update_playlist(url, config)
      end
    )
  end

  defp init do
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
    playlists_directory: String.t(),
    playlists: [String.t()],
  }

  @spec load_config!() :: Ytautodownloader.Config.t()
  def load_config! do
    with {:ok, body} <- File.read(Ytautodownloader.Constants.config_path()),
          {:ok, data} <- Jason.decode(body, keys: :atoms) do
      data |> IO.inspect()
      struct!(Ytautodownloader.Config, data)
    else
      {:error, %Jason.DecodeError{} = error} -> 
        throw("Invalid JSON in configuration file at byte #{error.position} in: #{error.data}")
      {:error, reason} ->
        throw("Could not read configuration file: #{reason}")
    end
  end

  @spec get_absolute_playlists_path(String.t()) :: String.t()
  def get_absolute_playlists_path(config_path) do
    # TODO: Probably should do more checking on the input
    case Path.type(config_path) do
      :relative -> Path.join(__DIR__, config_path)
      _ -> config_path
    end
  end

end

defmodule Ytautodownloader.Ytdlp do
  @doc """
  Updates a playlist fully. Can partially fail, if for example the downloading succeeds, but the metadata cannot be fetched.
  """
  @spec update_playlist(String.t(), Ytautodownloader.Config.t()) :: :ok | :error
  def update_playlist(url, config) do
    with  :ok <- download_playlist(url, config),
          :ok <- make_playlist_manifest(url, config)
    do
      :ok
    else
      :error -> :error
    end
  end

  @spec playlist_name(String.t(), Ytautodownloader.Config.t()) :: {:ok, String.t()} | :error
  def playlist_name(url, %Ytautodownloader.Config{cookies_from_browser: cookies_method}) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", cookies_method, # TODO: Accept options
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

  @spec playlist_songs_ids(String.t(), Ytautodownloader.Config.t()) :: {:ok, [String.t()]} | :error
  def playlist_songs_ids(url, %Ytautodownloader.Config{cookies_from_browser: cookies_method}) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", cookies_method,
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

  @spec make_playlist_manifest(String.t(), Ytautodownloader.Config.t()) :: :ok | :error
  def make_playlist_manifest(url, %Ytautodownloader.Config{playlists_directory: playlists_directory} = config) do
    IO.puts("Making playlist manifest (.m3u) file for #{url}")

    with  {:ok, p_name} <- playlist_name(url, config),
          {:ok, p_songs} <- playlist_songs_ids(url, config)
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

  # TODO: This function returns an error when a video is unavailable... Should we silently fail on unavailable videos
  @spec download_playlist(String.t(), Ytautodownloader.Config.t()) :: :ok | :error
  def download_playlist(url, %Ytautodownloader.Config{cookies_from_browser: cookies_method}) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", cookies_method,
      "--embed-metadata",
      "--embed-thumbnail",
      "--convert-thumbnails", "jpg",
      "--audio-quality", "0",
      "-x",
      "--audio-format", "mp3",
      "-f", "ba",
      "--windows-filenames",
      "--download-archive", Path.join(Ytautodownloader.Constants.downloads_path(), "!ARCHIVE!.txt"),
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
