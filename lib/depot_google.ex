defmodule DepotGoogle do
  @moduledoc """
  Depot adapter for Google Cloud Storage.

  ## Direct usage

      metadata = [contentType: "text/plain"]
      filesystem = DepotGoogle.configure(bucket: "default", metadata: metadata)
      :ok = Depot.write(filesystem, "test.txt", "Hello World")
      {:ok, "Hello World"} = Depot.read(filesystem, "test.txt")

  ## Usage with a module

      defmodule MyFileSystem do
        use Depot,
          adapter: DepotGoogle,
          bucket: "default",
          account: "account@myproject.iam.gserviceaccount.com",
          metadata: [
            storageClass: "STANDARD"
          ]
      end

      MyFileSystem.write("test.txt", "Hello World")
      {:ok, "Hello World"} = MyFileSystem.read("test.txt")
  """
  alias GoogleApi.Storage.V1.Api.Objects, as: Google

  defmodule Config do
    @moduledoc false
    defstruct bucket: nil, prefix: nil, account: nil, metadata: nil
  end

  @behaviour Depot.Adapter

  @impl Depot.Adapter
  def starts_processes, do: false

  @impl Depot.Adapter
  def configure(opts) do
    metadata = struct(GoogleApi.Storage.V1.Model.Object, Keyword.get(opts, :metadata, []))

    config = %Config{
      bucket: Keyword.fetch!(opts, :bucket),
      prefix: Keyword.get(opts, :prefix, ""),
      account: Keyword.get(opts, :account, :default),
      metadata: metadata
    }

    {__MODULE__, config}
  end

  defp new_conn(account) do
    case Goth.Token.for_scope({account, "https://www.googleapis.com/auth/devstorage.read_write"}) do
      {:ok, %{token: token}} -> {:ok, GoogleApi.Storage.V1.Connection.new(token)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Depot.Adapter
  def write(%Config{} = config, path, contents) do
    path = Depot.RelativePath.join_prefix(config.prefix, path)
    metadata = Map.put(config.metadata, :name, path)

    with {:ok, conn} <- new_conn(config.account),
         {:ok, _} <- insert_iodata(conn, config.bucket, metadata, contents) do
      :ok
    end
  end

  # uploading iodata using the official library is broken so we have to
  # reimplement it with changes below for now
  # https://github.com/googleapis/elixir-google-api/pull/3638
  defp insert_iodata(conn, bucket, metadata, contents) do
    alias GoogleApi.Gax.{Request, Response}

    body =
      Tesla.Multipart.new()
      |> Tesla.Multipart.add_field("metadata", Poison.encode!(metadata),
        headers: [{:"Content-Type", "application/json"}]
      )
      |> Tesla.Multipart.add_file_content(contents, "data")

    request =
      Request.new()
      |> Request.method(:post)
      |> Request.url("/upload/storage/v1/b/{bucket}/o", %{
        "bucket" => URI.encode(bucket, &URI.char_unreserved?/1)
      })
      |> Request.add_param(:query, :uploadType, "multipart")
      |> Request.add_param(:body, :body, body)
      |> Request.library_version("0.3.2")

    conn
    |> GoogleApi.Storage.V1.Connection.execute(request)
    |> Response.decode(struct: %GoogleApi.Storage.V1.Model.Object{})
  end

  @impl Depot.Adapter
  def read(%Config{} = config, path) do
    path = Depot.RelativePath.join_prefix(config.prefix, path)

    with {:ok, conn} <- new_conn(config.account) do
      case Google.storage_objects_get(conn, config.bucket, path, [alt: "media"], decode: false) do
        {:ok, %{body: body}} -> {:ok, body}
        {:error, %{status: 404}} -> {:error, :enoent}
        rest -> rest
      end
    end
  end

  @impl Depot.Adapter
  def delete(%Config{} = config, path) do
    path = Depot.RelativePath.join_prefix(config.prefix, path)

    with {:ok, conn} <- new_conn(config.account) do
      case Google.storage_objects_delete(conn, config.bucket, path) do
        {:ok, _} -> :ok
        {:error, %{status: 404}} -> :ok
        rest -> rest
      end
    end
  end

  @impl Depot.Adapter
  def move(%Config{} = config, source, destination) do
    with :ok <- copy(config, source, destination) do
      delete(config, source)
    end
  end

  @impl Depot.Adapter
  def copy(%Config{} = config, source, destination) do
    source = Depot.RelativePath.join_prefix(config.prefix, source)
    destination = Depot.RelativePath.join_prefix(config.prefix, destination)

    with {:ok, conn} <- new_conn(config.account) do
      case rewrite(conn, config.bucket, source, destination) do
        {:ok, _} -> :ok
        {:error, %{status: 404}} -> {:error, :enoent}
        rest -> rest
      end
    end
  end

  defp rewrite(conn, bucket, source, destination, params \\ []) do
    case Google.storage_objects_rewrite(
           conn,
           bucket,
           source,
           bucket,
           destination,
           params
         ) do
      {:ok, %{done: false, rewriteToken: token}} ->
        rewrite(conn, bucket, source, destination, rewriteToken: token)

      rest ->
        rest
    end
  end

  @impl Depot.Adapter
  def file_exists(%Config{} = config, path) do
    path = Depot.RelativePath.join_prefix(config.prefix, path)

    with {:ok, conn} <- new_conn(config.account) do
      case Google.storage_objects_get(conn, config.bucket, path) do
        {:ok, _} -> {:ok, :exists}
        {:error, %{status: 404}} -> {:ok, :missing}
        rest -> rest
      end
    end
  end

  @impl Depot.Adapter
  def list_contents(%Config{} = config, path) do
    path = Depot.RelativePath.join_prefix(config.prefix, path)

    with {:ok, conn} <- new_conn(config.account),
         {:ok, %{items: files}} <- Google.storage_objects_list(conn, config.bucket, prefix: path) do
      contents =
        for file <- files do
          %Depot.Stat.File{
            name: Depot.RelativePath.strip_prefix(config.prefix, file.name),
            size: String.to_integer(file.size),
            mtime: file.updated
          }
        end

      {:ok, contents}
    end
  end
end
