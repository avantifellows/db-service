defmodule DbserviceWeb.GurukulConfigJSON do
  def show(%{config: config, resolved_from: resolved_from}) do
    %{
      config: config,
      resolved_from: resolved_from
    }
  end

  def error(%{error: message}) do
    %{error: message}
  end
end
