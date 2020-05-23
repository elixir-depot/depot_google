defmodule DepotS3.Minio do
  def start_link do
    MinioServer.start_link(config())
  end

  def config do
    [
      access_key_id: "minio_key",
      secret_access_key: "minio_secret",
      scheme: "http://",
      region: "local",
      host: "127.0.0.1",
      port: 9000
    ]
  end

  def initialize_bucket(name) do
    ExAws.S3.put_bucket(name, Keyword.fetch!(config(), :region))
    |> ExAws.request(config())
  end

  def recreate_bucket(name) do
    {:ok, _} =
      ExAws.S3.delete_bucket(name)
      |> ExAws.request(config())

    {:ok, _} =
      ExAws.S3.put_bucket(name, Keyword.fetch!(config(), :region))
      |> ExAws.request(config())
  end

  def clean_bucket(name) do
    {:ok, %{body: %{contents: list}}} =
      ExAws.S3.list_objects(name)
      |> ExAws.request(config())

    for item <- list do
      ExAws.S3.delete_object(name, item.key) |> ExAws.request(config())
    end
  end
end
