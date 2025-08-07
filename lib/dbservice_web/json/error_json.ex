defmodule DbserviceWeb.ErrorJSON do
  def render("500.json", _assigns) do
    %{errors: %{detail: "Internal Server Error"}}
  end

  # Optionally, add other error handlers:
  def render("404.json", _assigns) do
    %{errors: %{detail: "Not Found"}}
  end

  def render("400.json", _assigns) do
    %{errors: %{detail: "Bad Request"}}
  end

  # Fallback for any other status
  def render(_template, _assigns) do
    %{errors: %{detail: "Unknown error"}}
  end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
