defmodule DbserviceWeb.ImportLive.Index do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport
  alias Dbservice.Utils.Util
  import Phoenix.HTML, only: [raw: 1]

  @impl true
  def mount(_params, _session, socket) do
    imports = DataImport.list_imports()
    {:ok, assign(socket, imports: imports)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
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
      <div class="max-w-7xl mx-auto px-4 py-10 sm:px-6 lg:px-8">
        <!-- Header with glass morphism effect -->
        <div class="mb-10 backdrop-blur-sm bg-white/80 dark:bg-gray-800/80 rounded-2xl p-6 shadow-lg border border-gray-100 dark:border-gray-700">
          <div class="flex justify-between items-center">
            <h1 class="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600 dark:from-indigo-400 dark:to-violet-400">
              DATA IMPORTS
            </h1>

            <%= live_redirect to: Routes.live_path(@socket, DbserviceWeb.ImportLive.New),
                class: "group relative flex items-center px-6 py-3 overflow-hidden rounded-xl bg-gradient-to-r from-indigo-600 to-violet-600 text-white font-medium transition-all duration-300 hover:scale-105 hover:shadow-lg" do %>
              <span class="absolute inset-0 bg-white/10 opacity-0 transition-opacity group-hover:opacity-100"></span>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              New Import
            <% end %>
          </div>
        </div>

        <!-- Stats overview cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
            <div class="flex items-center">
              <div class="p-3 rounded-xl bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Completed</p>
                <p class="text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "completed") %></p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
            <div class="flex items-center">
              <div class="p-3 rounded-xl bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500 dark:text-gray-400">In Progress</p>
                <p class="text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "processing") %></p>
              </div>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-md border border-gray-100 dark:border-gray-700 transition-all duration-300 hover:shadow-lg">
            <div class="flex items-center">
              <div class="p-3 rounded-xl bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Failed</p>
                <p class="text-2xl font-bold text-gray-900 dark:text-white"><%= Enum.count(@imports, & &1.status == "failed") %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Main table with improved styling -->
        <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-md overflow-hidden border border-gray-100 dark:border-gray-700">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-800">
                <tr>
                  <th scope="col" class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Type</th>
                  <th scope="col" class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Status</th>
                  <th scope="col" class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Progress</th>
                  <th scope="col" class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Created</th>
                  <th scope="col" class="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
                <%= if Enum.empty?(@imports) do %>
                  <tr>
                    <td colspan="5" class="px-6 py-12 text-center text-gray-500 dark:text-gray-400">
                      <div class="flex flex-col items-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mb-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                        <div class="flex items-center">
                          <%= get_type_icon(import.type) %>
                          <span class="ml-2"><%= import.type %></span>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm">
                        <%= get_status_badge(import.status) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">
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
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">
                        <div class="flex flex-col">
                          <span><%= format_date(import.inserted_at) %></span>
                          <span class="text-xs text-gray-500 dark:text-gray-400"><%= format_time(import.inserted_at) %></span>
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm">
                        <div class="flex space-x-2">
                          <%= live_redirect to: Routes.live_path(@socket, DbserviceWeb.ImportLive.Show, import.id),
                              class: "inline-flex items-center justify-center p-2 rounded-lg text-indigo-600 hover:text-indigo-800 hover:bg-indigo-100 dark:text-indigo-400 dark:hover:text-indigo-300 dark:hover:bg-indigo-900/30 transition-colors" do %>
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                              <path d="M10 12a2 2 0 100-4 2 2 0 000 4z" />
                              <path fill-rule="evenodd" d="M.458 10C1.732 5.943 5.522 3 10 3s8.268 2.943 9.542 7c-1.274 4.057-5.064 7-9.542 7S1.732 14.057.458 10zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
                            </svg>
                            <span class="sr-only">View</span>
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
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
      <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-green-400 dark:text-green-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Completed
    </span>
    """)
  end

  defp get_status_badge("processing") do
    raw("""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400">
      <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-amber-400 dark:text-amber-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Processing
    </span>
    """)
  end

  defp get_status_badge("failed") do
    raw("""
    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-400">
      <svg class="-ml-0.5 mr-1.5 h-2 w-2 text-rose-400 dark:text-rose-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Failed
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
end
