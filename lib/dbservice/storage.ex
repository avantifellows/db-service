defmodule Dbservice.Storage do
  @moduledoc """
  Storage backend for CSV import files.

  When the `CSV_BUCKET` env var is set, files live in S3. Otherwise they
  live on the local filesystem under priv/static/uploads/. This lets the
  app run unchanged on EC2 (no bucket needed) while supporting Fargate's
  ephemeral filesystem (where local writes don't persist across tasks).

  Functions that need a local path for streaming (e.g. CSV parsing via
  `File.stream!/1`) call `local_path/1`, which downloads the object from
  S3 to a deterministic temp path on first call and is a no-op on
  subsequent calls. `delete/1` removes both the S3 object and any cached
  temp file.
  """

  @local_dir ["priv", "static", "uploads"]
  @temp_prefix "dbservice-import"

  def put(content, filename) do
    case bucket() do
      nil -> put_local(content, filename)
      bucket -> put_s3(bucket, content, filename)
    end
  end

  def read(filename) do
    case bucket() do
      nil -> File.read(local_path_on_disk(filename))
      bucket -> read_s3(bucket, filename)
    end
  end

  @doc """
  Returns a local filesystem path to the file. For the S3 backend, this
  downloads to a deterministic temp path on first call and reuses the
  cached file on subsequent calls. Use `delete/1` to clean up.
  """
  def local_path(filename) do
    case bucket() do
      nil ->
        {:ok, local_path_on_disk(filename)}

      bucket ->
        path = temp_path(filename)

        if File.exists?(path) do
          {:ok, path}
        else
          download_to(bucket, filename, path)
        end
    end
  end

  def delete(filename) do
    case bucket() do
      nil ->
        File.rm(local_path_on_disk(filename))

      bucket ->
        _ = File.rm(temp_path(filename))
        delete_s3(bucket, filename)
    end
  end

  defp bucket, do: System.get_env("CSV_BUCKET")

  defp local_path_on_disk(filename), do: Path.join(@local_dir ++ [filename])

  defp temp_path(filename) do
    Path.join(System.tmp_dir!(), "#{@temp_prefix}-#{filename}")
  end

  defp put_local(content, filename) do
    path = local_path_on_disk(filename)
    File.mkdir_p!(Path.dirname(path))

    case File.write(path, content) do
      :ok -> {:ok, filename}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_s3(bucket, content, filename) do
    case bucket |> ExAws.S3.put_object(filename, content) |> ExAws.request() do
      {:ok, _} -> {:ok, filename}
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_s3(bucket, filename) do
    case bucket |> ExAws.S3.get_object(filename) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp download_to(bucket, filename, path) do
    case bucket |> ExAws.S3.get_object(filename) |> ExAws.request() do
      {:ok, %{body: body}} ->
        case File.write(path, body) do
          :ok -> {:ok, path}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_s3(bucket, filename) do
    case bucket |> ExAws.S3.delete_object(filename) |> ExAws.request() do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
