defmodule DbserviceWeb.ImportLive.Index do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport
  alias Dbservice.Utils.Util
  import Phoenix.HTML, only: [raw: 1]
  import DbserviceWeb.Components.ImportStopModal

  @impl true
  def mount(_params, _session, socket) do
    imports = DataImport.list_imports()

    # Subscribe to import updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Dbservice.PubSub, "imports")
    end

    # Track import statuses to avoid duplicate notifications
    import_statuses =
      imports
      |> Enum.map(&{&1.id, &1.status})
      |> Enum.into(%{})

    {:ok, assign(socket, imports: imports, import_statuses: import_statuses)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_stop_modal", %{"import_id" => import_id}, socket) do
    import_id = String.to_integer(import_id)
    selected_import = Enum.find(socket.assigns.imports, &(&1.id == import_id))
    {:noreply, assign(socket, show_stop_modal: true, selected_import: selected_import)}
  end

  @impl true
  def handle_event("hide_stop_modal", _params, socket) do
    {:noreply, assign(socket, show_stop_modal: false, selected_import: nil)}
  end

  @impl true
  def handle_event("confirm_halt_import", _params, socket) do
    case DataImport.halt_import(socket.assigns.selected_import.id) do
      {:ok, _updated_import} ->
        {:noreply,
         socket
         |> assign(show_stop_modal: false, selected_import: nil)
         |> put_flash(:info, "Import has been stopped successfully.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(show_stop_modal: false, selected_import: nil)
         |> put_flash(:error, "Failed to halt import: #{reason}")}
    end
  end

  @impl true
  def handle_info({:import_updated, import_id}, socket) do
    # Refresh the imports list when any import is updated
    imports = DataImport.list_imports()

    # Check if this import status changed to a terminal state
    updated_import = Enum.find(imports, &(&1.id == import_id))
    previous_status = Map.get(socket.assigns.import_statuses, import_id)

    socket =
      if should_show_notification?(previous_status, updated_import) do
        handle_import_notification(socket, updated_import)
      else
        socket
      end

    # Update the import statuses map
    new_import_statuses =
      if updated_import do
        Map.put(socket.assigns.import_statuses, import_id, updated_import.status)
      else
        socket.assigns.import_statuses
      end

    {:noreply, assign(socket, imports: imports, import_statuses: new_import_statuses)}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, :page_title, "Data Imports")
  end

  defp apply_action(socket, _action, _params) do
    assign(socket, :page_title, "Data Imports")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
      <div class="max-w-7xl mx-auto px-3 py-6 sm:px-6 sm:py-10 lg:px-8">
        <!-- Header with glass morphism effect -->
        <div class="mb-6 sm:mb-10 backdrop-blur-sm bg-white/80 dark:bg-gray-800/80 rounded-xl sm:rounded-2xl p-4 sm:p-6 shadow-lg border border-gray-100 dark:border-gray-700">
          <div class="flex flex-col sm:flex-row justify-between items-center gap-4 sm:gap-0">
            <h1 class="text-2xl sm:text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600 dark:from-indigo-400 dark:to-violet-400">
              DATA IMPORTS
            </h1>

            <.link navigate={~p"/imports/new"}
                class="w-full sm:w-auto group relative flex items-center justify-center px-4 sm:px-6 py-2 sm:py-3 overflow-hidden rounded-xl bg-gradient-to-r from-indigo-600 to-violet-600 text-white font-medium transition-all duration-300 hover:scale-105 hover:shadow-lg">
              <span class="absolute inset-0 bg-white/10 opacity-0 transition-opacity group-hover:opacity-100"></span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              New Import
            </.link>
          </div>
        </div>

        <!-- Stats overview cards -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <div class="bg-white dark:bg-gray-800 rounded-xl sm:rounded-2xl p-4 sm:p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
            <div class="flex items-center">
              <div class="flex items-center justify-center p-2 sm:p-3 rounded-lg sm:rounded-xl bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400">
               <svg xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 sm:h-6 sm:w-6"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round">
                  <!-- Checkmark -->
                  <path d="M9 12l2 2 4-4" />
                  <!-- Circle -->
                  <circle cx="12" cy="12" r="9" />
                </svg>

              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Completed</p>
                <p class="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "completed") %></p>
              </div>
            </div>
            </div>

            <div class="bg-white dark:bg-gray-800 rounded-xl sm:rounded-2xl p-4 sm:p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
              <div class="flex items-center">
               <div class="flex items-center justify-center p-2 sm:p-3 rounded-lg sm:rounded-xl bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400">
                  <svg xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5 sm:h-6 sm:w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round">
                    <!-- Clock hands -->
                    <path d="M12 8v4l3 3" />
                    <!-- Circle with same stroke width as path -->
                    <circle cx="12" cy="12" r="9" />
                  </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">In Progress</p>
                  <p class="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "processing") %></p>
                </div>
              </div>
            </div>

            <div class="bg-white dark:bg-gray-800 rounded-xl sm:rounded-2xl p-4 sm:p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
              <div class="flex items-center">
                <div class="flex items-center justify-center p-2 sm:p-3 rounded-lg sm:rounded-xl bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400">
                   <svg xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 sm:h-6 sm:w-6"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2">
                  <!-- Circle -->
                  <circle cx="12" cy="12" r="9" />
                  <!-- Centered X -->
                  <path stroke-linecap="round" stroke-linejoin="round"
                        d="M9 9l6 6m0-6l-6 6" />
                   </svg>
                </div>
                <div class="ml-4">
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Stopped</p>
                  <p class="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "stopped") %></p>
                </div>
              </div>
            </div>

            <div class="bg-white dark:bg-gray-800 rounded-xl sm:rounded-2xl p-4 sm:p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
              <div class="flex items-center">

                  <div class="flex items-center justify-center p-2 sm:p-3 rounded-lg sm:rounded-xl bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400">
                  <svg xmlns="http://www.w3.org/2000/svg"
                      class="h-5 w-5 sm:h-6 sm:w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round">
                    <!-- Rounded triangle -->
                    <path d="M12 3 L21 20 H3 Z" fill="none" stroke="currentColor" />
                    <!-- Exclamation mark -->
                    <line x1="12" y1="9" x2="12" y2="14" />
                    <circle cx="12" cy="17" r="1" fill="currentColor" stroke="none" />
                  </svg>
                </div>


                <div class="ml-4">
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Failed</p>
                  <p class="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "failed") %></p>
                </div>
              </div>
          </div>
        </div>

        <!-- Main table with improved styling -->
        <div class="bg-white dark:bg-gray-800 rounded-xl sm:rounded-2xl shadow-md overflow-hidden border border-gray-100 dark:border-gray-700">
          <!-- Mobile view (card style for small screens) -->
          <div class="block sm:hidden">
            <%= if Enum.empty?(@imports) do %>
              <div class="p-6 text-center text-gray-500 dark:text-gray-400">
                <div class="flex flex-col items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mb-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                  </svg>
                  <p class="text-lg font-medium">No imports found</p>
                  <p class="mt-1">Click "New Import" to get started</p>
                </div>
              </div>
            <% else %>
              <div class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= for import <- @imports do %>
                  <div class="p-4">
                    <div class="flex justify-between items-start mb-2">
                      <div class="flex items-center">
                        <%= get_type_icon(import.type) %>
                        <span class="ml-2 font-medium text-gray-900 dark:text-white"><%= DataImport.format_type_name(import.type) %></span>
                      </div>
                      <%= get_status_badge(import.status) %>
                    </div>

                    <div class="mb-3 text-gray-500">
                      <div class="flex justify-between text-xs font-medium mb-1">
                        <span><%= import.processed_rows %>/<%= import.total_rows %></span>
                        <span><%= calculate_percentage(import.processed_rows, import.total_rows) %>%</span>
                      </div>
                      <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-gradient-to-r from-indigo-500 to-violet-500 h-2 rounded-full" style={"width: #{calculate_percentage(import.processed_rows, import.total_rows)}%"}></div>
                      </div>
                    </div>

                    <div class="flex justify-between items-center">
                      <div class="text-xs text-gray-500 dark:text-gray-400">
                        <%= format_date(import.inserted_at) %> at <%= format_time(import.inserted_at) %>
                      </div>
                      <div class="flex space-x-2">
                        <.link navigate={~p"/imports/#{import.id}"}
                            class="inline-flex items-center justify-center p-2 rounded-lg text-indigo-600 hover:text-indigo-800 hover:bg-indigo-100 dark:text-indigo-400 dark:hover:text-indigo-300 dark:hover:bg-indigo-900/30 transition-colors">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                            <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
                          </svg>
                          <span class="sr-only">View</span>
                        </.link>

                        <%= if import.status in ["processing", "pending"] do %>
                          <button
                            phx-click="show_stop_modal"
                            phx-value-import_id={import.id}
                            class="inline-flex items-center justify-center p-2 rounded-lg text-red-600 hover:text-red-800 hover:bg-red-100 dark:text-red-400 dark:hover:text-red-300 dark:hover:bg-red-900/30 transition-colors">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                              <path stroke-linecap="round" stroke-linejoin="round" d="M9 10l6 6m0-6l-6 6" />
                            </svg>
                            <span class="sr-only">Stop</span>
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <!-- Desktop view (table for larger screens) -->
          <div class="hidden sm:block overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-800">
                <tr>
                <th scope="col" class="px-4 sm:px-6 py-3 sm:py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Type</th>
                <th scope="col" class="px-4 sm:px-6 py-3 sm:py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Status</th>
                  <th scope="col" class="px-8 sm:px-12 py-3 sm:py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Progress</th>
                  <th scope="col" class="px-4 sm:px-6 py-3 sm:py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Created</th>
                  <th scope="col" class="px-4 sm:px-6 py-3 sm:py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= if Enum.empty?(@imports) do %>
                  <tr>
                    <td colspan="5" class="px-4 sm:px-6 py-8 sm:py-12 text-center text-gray-500 dark:text-gray-400">
                      <div class="flex flex-col items-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-10 sm:h-12 w-10 sm:w-12 mb-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                        </svg>
                        <p class="text-lg font-medium">No imports found</p>
                        <p class="mt-1">Click "New Import" to get started</p>
                      </div>
                    </td>
                  </tr>
                <% else %>
                  <%= for import <- @imports do %>
                    <tr class="hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors">
                    <td class="px-4 sm:px-6 py-3 sm:py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                    <div class="flex items-center">
                          <%= get_type_icon(import.type) %>
                          <span class="ml-2"><%= DataImport.format_type_name(import.type) %></span>
                        </div>
                      </td>
                      <td class="px-4 sm:px-6 py-3 sm:py-4 whitespace-nowrap text-sm">
                        <%= get_status_badge(import.status) %>
                      </td>
                      <td class="px-8 sm:px-12 py-3 sm:py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">
                        <div class="w-full max-w-xs">
                          <div class="flex justify-between mb-1 text-xs font-medium">
                            <span><%= import.processed_rows %>/<%= import.total_rows %></span>
                            <span><%= calculate_percentage(import.processed_rows, import.total_rows) %>%</span>
                          </div>
                          <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                            <div class="bg-gradient-to-r from-indigo-500 to-violet-500 h-2 rounded-full" style={"width: #{calculate_percentage(import.processed_rows, import.total_rows)}%"}></div>
                          </div>
                        </div>
                      </td>
                      <td class="px-4 sm:px-6 py-3 sm:py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">
                        <div class="flex flex-col">
                          <span><%= format_date(import.inserted_at) %></span>
                          <span class="text-xs text-gray-500 dark:text-gray-400"><%= format_time(import.inserted_at) %></span>
                        </div>
                      </td>
                      <td class="px-4 sm:px-6 py-3 sm:py-4 whitespace-nowrap text-sm">
                        <div class="flex space-x-2">
                          <.link navigate={~p"/imports/#{import.id}"}
                              class="inline-flex items-center justify-center p-2 rounded-lg text-indigo-600 hover:text-indigo-800 hover:bg-indigo-100 dark:text-indigo-400 dark:hover:text-indigo-300 dark:hover:bg-indigo-900/30 transition-colors">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                              <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                              <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
                            </svg>
                            <span class="sr-only">View</span>
                          </.link>

                          <%= if import.status in ["processing", "pending"] do %>
                            <button
                              phx-click="show_stop_modal"
                              phx-value-import_id={import.id}
                              class="inline-flex items-center justify-center p-2 rounded-lg text-red-600 hover:text-red-800 hover:bg-red-100 dark:text-red-400 dark:hover:text-red-300 dark:hover:bg-red-900/30 transition-colors">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-5 w-5 mx-auto"
                                fill="none"
                                viewBox="0 0 24 24"
                                stroke="currentColor"
                                stroke-width="2"
                              >
                                <!-- Circle -->
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                                />
                                <!-- Centered X -->
                                <path
                                  stroke-linecap="round"
                                  stroke-linejoin="round"
                                  d="M9 9l6 6m0-6l-6 6"
                                />
                              </svg>
                              <span class="sr-only">Stop</span>
                            </button>
                          <% end %>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Reusable confirmation modal for stopping import -->
        <.import_stop_modal
          show={@show_stop_modal}
          import={@selected_import}
          on_hide="hide_stop_modal"
          on_confirm="confirm_halt_import"
        />
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_date(datetime) do
    ist_datetime = datetime |> Util.naive_to_datetime() |> Util.to_ist()
    "#{ist_datetime.year}-#{pad(ist_datetime.month)}-#{pad(ist_datetime.day)}"
  end

  defp format_time(datetime) do
    ist_datetime = datetime |> Util.naive_to_datetime() |> Util.to_ist()
    "#{pad(ist_datetime.hour)}:#{pad(ist_datetime.minute)}"
  end

  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"

  defp calculate_percentage(processed, total) when total > 0 do
    round(processed / total * 100)
  end

  defp calculate_percentage(_, _), do: 0

  defp get_status_badge("completed") do
    raw("""
    <span class="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400 min-h-[1.5rem]">
      <svg class="mr-1.5 h-2.5 w-2.5 text-green-400 dark:text-green-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Completed
    </span>
    """)
  end

  defp get_status_badge("pending") do
    raw("""
    <span class="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400 min-h-[1.5rem]">
      <svg class="mr-1.5 h-2.5 w-2.5 text-blue-400 dark:text-blue-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Pending
    </span>
    """)
  end

  defp get_status_badge("processing") do
    raw("""
    <span class="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400 min-h-[1.5rem]">
      <svg class="mr-1.5 h-2.5 w-2.5 text-amber-400 dark:text-amber-500 animate-pulse" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Processing
    </span>
    """)
  end

  defp get_status_badge("failed") do
    raw("""
    <span class="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-400 min-h-[1.5rem]">
      <svg class="mr-1.5 h-2.5 w-2.5 text-rose-400 dark:text-rose-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Failed
    </span>
    """)
  end

  defp get_status_badge("stopped") do
    raw("""
    <span class="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400 min-h-[1.5rem]">
      <svg class="mr-1.5 h-2.5 w-2.5 text-orange-400 dark:text-orange-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Stopped
    </span>
    """)
  end

  # Added a fallback clause for any unexpected status values
  defp get_status_badge(status) do
    raw("""
    <span class="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400 min-h-[1.5rem]">
      <svg class="mr-1.5 h-2.5 w-2.5 text-gray-400 dark:text-gray-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      #{status}
    </span>
    """)
  end

  defp get_type_icon("csv") do
    raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-green-500 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  defp get_type_icon("excel") do
    raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-blue-500 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2v-2" />
    </svg>
    """)
  end

  defp get_type_icon("json") do
    raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-yellow-500 dark:text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
    </svg>
    """)
  end

  defp get_type_icon(_) do
    raw("""
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-500 dark:text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  # Helper function to determine if we should show a notification
  # Only show notifications when transitioning to a terminal state (completed/failed)
  # and we haven't already shown a notification for this import
  defp should_show_notification?(previous_status, %{status: "failed"})
       when previous_status != "failed",
       do: true

  defp should_show_notification?(previous_status, %{status: "completed"})
       when previous_status != "completed",
       do: true

  defp should_show_notification?(_, _), do: false

  # Helper function to handle import notifications and reduce nesting
  defp handle_import_notification(socket, %{status: "failed"} = import) do
    error_message = extract_error_message(import.error_details)
    put_flash(socket, :error, "Import ##{import.id} failed: #{error_message}")
  end

  defp handle_import_notification(socket, %{status: "completed"} = import) do
    put_flash(
      socket,
      :info,
      "Import ##{import.id} completed successfully! Processed #{import.processed_rows} records."
    )
  end

  defp handle_import_notification(socket, _import), do: socket

  # Helper function to extract error message from error_details
  defp extract_error_message([%{"error" => error} | _]) when is_binary(error) do
    truncate_message(error)
  end

  defp extract_error_message([%{error: error} | _]) do
    error
    |> inspect()
    |> truncate_message()
  end

  defp extract_error_message(_), do: "Import failed with unknown error"

  # Helper function to truncate long messages
  defp truncate_message(message) when is_binary(message) do
    if String.length(message) > 100 do
      String.slice(message, 0, 100) <> "..."
    else
      message
    end
  end
end
