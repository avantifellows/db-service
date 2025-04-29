defmodule DbserviceWeb.ImportLive.New do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport
  import Phoenix.LiveView

  def mount(_params, _session, socket) do
    changeset = DataImport.change_import(%DataImport.Import{start_row: 2})
    form = Phoenix.Component.to_form(changeset)
    submission_token = generate_token()
    {:ok, assign(socket,
      form: form,
      changeset: changeset,
      submitting: false,
      submitted: false,
      debounce_timer: nil,
      submission_token: submission_token
    )}
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  def handle_event("validate", %{"import" => import_params}, socket) do
    changeset =
      %DataImport.Import{}
      |> DataImport.Import.changeset(import_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save", params, socket) do
    # Return early if already submitting or submitted
    if socket.assigns.submitting || socket.assigns.submitted do
      {:noreply, socket}
    else
      # Cancel any existing timer
      cancel_existing_timer(socket)

      # Set submitting to true immediately to disable the button
      socket = assign(socket, submitting: true)

      # Create a debounce timer to delay the actual form submission
      timer_ref = Process.send_after(self(), {:do_save, params}, 300)

      {:noreply, assign(socket, debounce_timer: timer_ref)}
    end
  end

  # Helper function to extract nested logic
  defp cancel_existing_timer(socket) do
    if socket.assigns.debounce_timer do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end
  end

  def handle_info({:do_save, params}, socket) do
    # Mark as submitted to prevent double-submission
    if socket.assigns.submitted do
      {:noreply, socket}
    else
      socket = assign(socket, submitted: true)
      handle_save(params, socket)
    end
  end

  defp handle_save(%{"import" => import_params}, socket) do
    # The import_params already contain the submission_token from the hidden field
    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        {:noreply,
         socket
         |> put_flash(:info, "Import submitted successfully!")
         |> push_navigate(to: ~p"/imports")}

      {:error, reason} when is_binary(reason) ->
        changeset =
          %DataImport.Import{}
          |> DataImport.Import.changeset(import_params)
          |> Ecto.Changeset.add_error(:sheet_url, reason)
          |> Map.put(:action, :validate)

        new_token = generate_token()

        {:noreply,
         assign(socket,
           changeset: changeset,
           submitting: false,
           submitted: false,
           debounce_timer: nil,
           submission_token: new_token
         )}
    end
  end

  defp handle_save(_, socket) do
    IO.puts("Unexpected empty parameters received!")
    {:noreply, assign(socket, submitting: false, submitted: false, debounce_timer: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
      <div class="max-w-7xl mx-auto px-4 py-10 sm:px-6 lg:px-8">
        <!-- Header with navigation -->
        <div class="mb-8 flex items-center">
          <.link navigate={~p"/imports"}
              class="group flex items-center text-sm font-medium text-gray-600 hover:text-indigo-600 dark:text-gray-400 dark:hover:text-indigo-400 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 transition-transform group-hover:-translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to imports
          </.link>
        </div>

        <!-- Main content card with glass morphism -->
        <div class="backdrop-blur-sm bg-white/90 dark:bg-gray-800/90 rounded-2xl shadow-lg border border-gray-100 dark:border-gray-700 overflow-hidden">
          <!-- Header section -->
          <div class="px-6 py-6 border-b border-gray-100 dark:border-gray-700">
            <h1 class="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600 dark:from-indigo-400 dark:to-violet-400">
              New Import
            </h1>
            <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
              Start a new data import from a Google Sheet
            </p>
          </div>

          <!-- Form section -->
          <div class="px-6 py-6">
            <.form
              for={@form}
              phx-submit="save"
              phx-change="validate"
              class="space-y-6"
            >
              <input type="hidden" name="import[submission_token]" value={@submission_token} />

              <!-- Type selection -->
              <div>
                <.input
                  type="select"
                  field={@form[:type]}
                  label="Import Type"
                  options={[{"Student", "student"}]}
                  class="block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                />
              </div>

              <!-- Google Sheet URL -->
              <div>
                <.input
                  type="text"
                  field={@form[:sheet_url]}
                  label="Google Sheet URL"
                  placeholder="https://docs.google.com/spreadsheets/d/..."
                  class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                >
                  <div class="mt-1 relative rounded-md shadow-sm">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                      </svg>
                    </div>
                  </div>
                  <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                    Make sure the sheet has been shared with the service account and has the correct format
                  </p>
                </.input>
              </div>

              <!-- Start Row -->
              <div>
                <.input
                  type="number"
                  field={@form[:start_row]}
                  label="Start Row Number"
                  min="1"
                  placeholder="2"
                  class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm dark:bg-gray-700 dark:border-gray-600 dark:text-white"
                >
                  <div class="mt-1 relative rounded-md shadow-sm">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                      </svg>
                    </div>
                  </div>
                  <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                    Row number to start importing data from (e.g. 2 to skip header row)
                  </p>
                </.input>
              </div>

              <!-- Submit button -->
              <div class="pt-4">
                <button type="submit"
                  class={"w-full flex justify-center items-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white #{if @submitting, do: "bg-indigo-400 cursor-not-allowed", else: "bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"}"}
                  disabled={@submitting}
                  phx-disable-with="Processing...">
                  <%= if @submitting do %>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-white animate-spin" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    Processing...
                  <% else %>
                    Start Import
                  <% end %>
                </button>
              </div>
            </.form>
          </div>

          <!-- Info section -->
          <div class="px-6 py-6 border-t border-gray-100 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900/30">
            <div class="flex items-start">
              <div class="flex-shrink-0">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-blue-500 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-3">
                <h3 class="text-sm font-medium text-gray-700 dark:text-gray-300">
                  Import Instructions
                </h3>
                <div class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  <p>Ensure your Google Sheet:</p>
                  <ul class="list-disc pl-5 mt-1 space-y-1">
                    <li>Has been shared with our service account (read access only is required)</li>
                    <li>Contains all required columns based on the import type</li>
                    <li>Has headers in the first row</li>
                    <li>Contains no merged cells</li>
                    <li>Use "Start Row" to skip header rows or additional content at the top of your sheet</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
