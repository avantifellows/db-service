defmodule DbserviceWeb.AuthHTML do
  @moduledoc """
  Templates for the Google SSO sign-in page.
  """

  use DbserviceWeb, :html

  embed_templates "auth_html/*"
end
