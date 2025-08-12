defmodule DbserviceWeb.ErrorJSON do
  require Logger

  def render("500.json", assigns) do
    Logger.error("Internal Server Error: #{inspect(assigns[:reason])}")

    message =
      case assigns[:reason] do
        %{message: msg} -> remove_special_chars(msg)
        nil -> "Internal Server Error"
        other -> other
      end

    %{errors: %{detail: "Internal Server Error", message: message}}
  end

  # Optionally, add other error handlers:
  def render("404.json", assigns) do
    Logger.error("Not Found: #{inspect(assigns[:reason])}")

    message =
      case assigns[:reason] do
        %{message: msg} -> remove_special_chars(msg)
        nil -> "Not Found"
        other -> other
      end

    %{errors: %{detail: "Not Found", message: message}}
  end

  def render("400.json", assigns) do
    Logger.error("Bad Request: #{inspect(assigns[:reason])}")

    message =
      case assigns[:reason] do
        %{message: msg} -> remove_special_chars(msg)
        nil -> "Invalid request"
        other -> other
      end

    %{errors: %{detail: "Bad Request", message: message}}
  end

  # Fallback for any other status
  def render(template, assigns) do
    Logger.error(
      "Unknown error - Template: #{inspect(template)}, Assigns: #{inspect(assigns[:reason])}"
    )

    message =
      case assigns[:reason] do
        %{message: msg} -> remove_special_chars(msg)
        nil -> "Unknown error"
        other -> other
      end

    %{errors: %{detail: "Unknown error", message: message}}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end

  def remove_special_chars(str) when is_binary(str) do
    str
    |> String.replace("\n", " ")
    |> String.replace("\"", "")
  end
end
