Mix.install([
  {:exqlite, "~> 0.13"}
])

defmodule Ytautodownloader.Constants do
  @yt_autodownload_dir Path.join(__DIR__, "yt-autodownload")
  @sqlite_db Path.join(@yt_autodownload_dir, "data.db")
  @downloads_dir Path.join(@yt_autodownload_dir, "downloads")

  def yt_autodownload_path, do: @yt_autodownload_dir
  def sqlite_db, do: @sqlite_db
  def downloads_path, do: @downloads_dir
end

defmodule Ytautodownloader do

  def main(args \\ []) do
    args |> IO.inspect()

    init()

    Ytautodownloader.Ytdlp.playlist_name("https://youtube.com/playlist?list=PLKLMsHwPzDZG4pXDwB2M7LwZYq6Rvx1dh") |> IO.inspect()
    Ytautodownloader.Ytdlp.playlist_songs_ids("https://youtube.com/playlist?list=PLKLMsHwPzDZG4pXDwB2M7LwZYq6Rvx1dh") |> IO.inspect()

    conn = sqlite_connect!()
    {:ok, statement} = Exqlite.Sqlite3.prepare(
      conn,
      "SELECT name FROM sqlite_schema WHERE type='table'"
    )
    {:ok, tables} = Exqlite.Sqlite3.fetch_all(conn, statement)
    tables |> IO.inspect(label: "tables")
  end

  defp init() do
    # Ensure directories exist
    case File.mkdir_p(Ytautodownloader.Constants.downloads_path) do
      :ok -> :ok
      {:error, _}
        -> IO.puts(:stderr, "Could not open/create directories")
    end
  end

  defp sqlite_connect!() do
    conn = case Exqlite.Sqlite3.open(Ytautodownloader.Constants.sqlite_db) do
      {:ok, conn} -> conn
      {:error, _} ->
        raise("Could not establish connection with Sqlite")
    end

    Exqlite.Sqlite3.execute(conn, 
      """
      CREATE TABLE IF NOT EXISTS playlists 
      (
        id INTEGER PRIMARY KEY, 
        url TEXT
      );
      CREATE TABLE IF NOT EXISTS songs
      (
        id INTEGER PRIMARY KEY,
        file_name TEXT,
        url TEXT
      );
      CREATE TABLE IF NOT EXISTS playlistsongs
      (
        playlist_id INTEGER,
        song_id INTEGER
      )
      """
    )

    conn
  end
end

defmodule Ytautodownloader.Config do
  defstruct [
    cookies_from_browser: "firefox",
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
        config_file = File.open(config_path, [:write])
    end
  end

end

defmodule Ytautodownloader.Ytdlp do
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

  @spec playlist_songs_ids(String.t()) :: [String.t()] | :error
  def playlist_songs_ids(url) do
    case System.cmd("yt-dlp", [
      "--cookies-from-browser", "firefox",
      "--flat-playlist",
      "--print", "id",
      url,
    ]) do
      {_, 1} -> :error
      {res, 0} ->
        res
        |> String.trim_trailing()
        |> String.split("\n")
    end
  end

  @spec download_playlist(String.t()) :: :ok | {:error, String.t()}
  def download_playlist(url) do
    System.cmd("yt-dlp", [
      "--cookies-from-browser", "firefox",
      "--embed-metadata",
      "--embed-thumbnail",
      "--convert-thumbnails", "jpg",
      "--audio-quality", "0",
      "-x",
      "--audio-format", "mp3",
      "-f", "ba",
      "--windows-filenames",
      "--download-archive", Path.join(Ytautodownloader.Constants.yt_autodownload_path, "__ARCHIVE__.txt"),
      "-o", Path.join(Ytautodownloader.Constants.yt_autodownload_path, "%(id)s.%(ext)s"),
      url,
    ])
  end
end

Ytautodownloader.main(System.argv())
