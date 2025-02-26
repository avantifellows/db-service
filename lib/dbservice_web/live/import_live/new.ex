defmodule DbserviceWeb.ImportLive.New do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport

  def mount(_params, _session, socket) do
    changeset = DataImport.change_import(%DataImport.Import{})
    {:ok, assign(socket, changeset: changeset, submitting: false)}
  end

  def handle_event("validate", %{"import" => import_params}, socket) do
    # Create an empty Import struct first
    changeset =
      %Dbservice.DataImport.Import{}
      |> Dbservice.DataImport.Import.changeset(import_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"import" => import_params}, socket) do
    # Check if we're already processing a submission
    if socket.assigns.submitting do
      {:noreply, socket}
    else
      # Mark that we're processing the submission
      socket = assign(socket, submitting: true)

      case DataImport.start_import(import_params) do
        {:ok, _import} ->
          {:noreply, push_redirect(socket, to: "/imports")}

        {:error, reason} when is_binary(reason) ->
          changeset =
            %DataImport.Import{}
            |> DataImport.Import.changeset(import_params)
            |> Ecto.Changeset.add_error(:sheet_url, reason)
            |> Map.put(:action, :validate)

          {:noreply, assign(socket, changeset: changeset, submitting: false)}

        {:error, changeset} ->
          {:noreply, assign(socket, changeset: changeset, submitting: false)}
      end
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-3xl font-semibold text-gray-900">New Import</h1>
      </div>

      <div class="mt-6 max-w-3xl">
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-disable-with="Processing...">
      <div class="space-y-6 sm:space-y-5">
            <div class="sm:grid sm:grid-cols-3 sm:gap-4 sm:items-start">
              <label class="block text-sm font-medium text-gray-700 sm:mt-px sm:pt-2">
                Type
              </label>
              <div class="mt-1 sm:mt-0 sm:col-span-2">
                <%= Phoenix.HTML.Form.select(f, :type, [{"Student", "student"}], class: "max-w-lg block w-full shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:max-w-xs sm:text-sm border-gray-300 rounded-md") %>
              </div>
            </div>

            <div class="sm:grid sm:grid-cols-3 sm:gap-4 sm:items-start">
              <label class="block text-sm font-medium text-gray-700 sm:mt-px sm:pt-2">
                Google Sheet URL
              </label>
              <div class="mt-1 sm:mt-0 sm:col-span-2">
              <%= Phoenix.HTML.Form.text_input(f, :sheet_url, class: "max-w-lg block w-full shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm border-gray-300 rounded-md", placeholder: "https://docs.google.com/spreadsheets/d/...") %>
              </div>
            </div>
          </div>

          <div class="mt-8 sm:mt-10">
            <%= Phoenix.HTML.Form.submit "Start Import", class: "inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500", disabled: @submitting %>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
