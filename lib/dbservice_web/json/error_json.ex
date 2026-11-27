defmodule DbserviceWeb.ErrorJSON do
  require Logger

  @malformed_body "malformed request body"

  # A body Plug.Parsers cannot parse, such as truncated JSON. The exception holds
  # the raw body, which can carry free text, so neither the log line nor the
  # response includes it (the exception is not JSON-encodable either). The Visit
  # Concern API answers in its own `%{error: message}` shape.
  def render("400.json", %{reason: %Plug.Parsers.ParseError{}} = assigns) do
    Logger.error("Bad Request: #{@malformed_body}")

    case assigns do
      %{conn: %Plug.Conn{path_info: ["api", "visit-concerns" | _]}} ->
        %{error: @malformed_body}

      _ ->
        %{errors: %{detail: "Bad Request", message: @malformed_body}}
    end
  end

  def render(template, assigns) do
    {detail, default_message} =
      case template do
        "500.json" -> {"Internal Server Error", "Internal Server Error"}
        "404.json" -> {"Not Found", "Not Found"}
        "400.json" -> {"Bad Request", "Invalid request"}
        "422.json" -> {"Unprocessable Entity", "Validation failed"}
        _ -> {"Unknown error", "Unknown error"}
      end

    Logger.error("#{detail}: #{inspect(assigns[:reason])}")

    message =
      case assigns[:reason] do
        %{message: msg} -> remove_special_chars(msg)
        nil -> default_message
        other -> other
      end

    %{errors: %{detail: detail, message: message}}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end

  def remove_special_chars(nil), do: ""

  def remove_special_chars(str) when is_binary(str) do
    str
    |> String.replace("\n", " ")
    |> String.replace("\"", "")
  end
end
