defmodule DbserviceWeb.ImportLive.Show do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport
  alias Dbservice.Utils.Util
  import Phoenix.HTML, only: [raw: 1]
  import DbserviceWeb.Components.ImportStopModal

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    import_record = DataImport.get_import!(id)

    # Subscribe to import updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Dbservice.PubSub, "imports")
    end

    {:ok, assign(socket, import: import_record, show_stop_modal: false)}
  end

  @impl true
  def handle_info({:import_updated, import_id}, socket) do
    # Only update if this is the import we're viewing
    if socket.assigns.import.id == import_id do
      import_record = DataImport.get_import!(import_id)
      {:noreply, assign(socket, import: import_record)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_stop_modal", _params, socket) do
    {:noreply, assign(socket, show_stop_modal: true)}
  end

  @impl true
  def handle_event("hide_stop_modal", _params, socket) do
    {:noreply, assign(socket, show_stop_modal: false)}
  end

  @impl true
  def handle_event("confirm_halt_import", _params, socket) do
    case DataImport.halt_import(socket.assigns.import.id) do
      {:ok, _updated_import} ->
        {:noreply,
         socket
         |> assign(show_stop_modal: false)
         |> put_flash(:info, "Import has been stopped successfully.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(show_stop_modal: false)
         |> put_flash(:error, "Failed to halt import: #{reason}")}
    end
  end

  @impl true
  def handle_event("halt_import", _params, socket) do
    case DataImport.halt_import(socket.assigns.import.id) do
      {:ok, _updated_import} ->
        {:noreply, put_flash(socket, :info, "Import has been stopped successfully.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to halt import: #{reason}")}
    end
  end

  defp parse_error_details(error_details) when is_list(error_details) do
    Enum.map(error_details, fn
      detail when is_map(detail) ->
        detail

      detail when is_binary(detail) ->
        try do
          # Attempt to parse JSON-like string
          case Jason.decode(detail) do
            {:ok, parsed_detail} ->
              parsed_detail

            _ ->
              # Fallback parsing for string-encoded error
              %{
                "row" => extract_row(detail),
                "error" => detail
              }
          end
        rescue
          _ ->
            %{
              "row" => "Unknown",
              "error" => detail
            }
        end

      _ ->
        %{
          "row" => "Unknown",
          "error" => "Unprocessable error format"
        }
    end)
  end

  defp parse_error_details(_), do: []

  defp extract_row(error_string) do
    # Try to extract row number from the error string
    case Regex.run(~r/row\s*(\d+)/, error_string) do
      [_, row] -> row
      _ -> "Unknown"
    end
  end

  @impl true
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
          <!-- Header section with status -->
          <div class="px-6 py-6 border-b border-gray-100 dark:border-gray-700">
            <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
              <div>
                <h1 class="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-600 dark:from-indigo-400 dark:to-violet-400">
                  Import Details
                </h1>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  ID: <%= @import.id %>
                </p>
              </div>

              <div class="flex items-center gap-3">
                <%= status_badge(@import.status) %>

                <%= if @import.status in ["processing", "pending"] do %>
                  <button
                    phx-click="show_stop_modal"
                    class="inline-flex items-center px-3 py-2 border border-red-300 shadow-sm text-sm leading-4 font-medium rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 dark:bg-gray-800 dark:border-red-600 dark:text-red-400 dark:hover:bg-red-900/20">
                    <svg class="-ml-0.5 mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10l6 6m0-6l-6 6"></path>
                    </svg>
                    Stop Import
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Progress section -->
          <div class="px-6 py-6 border-b border-gray-100 dark:border-gray-700 bg-gray-50/50 dark:bg-gray-900/30">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Progress</h2>

            <div class="flex flex-col">
              <!-- Progress indicator -->
              <div class="mb-4">
                <div class="flex justify-between mb-1 text-sm font-medium text-gray-700 dark:text-gray-300">
                  <span><%= @import.processed_rows %> of <%= @import.total_rows %> records processed</span>
                  <span><%= progress_percentage(@import) %>%</span>
                </div>
                <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
                  <div class={progress_bar_classes(@import.status)} style={"width: #{progress_percentage(@import)}%"}></div>
                </div>
              </div>

              <!-- Stats cards -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
                <div class="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-700">
                  <div class="flex items-center">
                    <div class="p-2 rounded-lg bg-indigo-100 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Type</p>
                      <p class="text-sm font-semibold text-gray-900 dark:text-white"><%= DataImport.format_type_name(@import.type) %></p>
                    </div>
                  </div>
                </div>

                <div class="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-700">
                  <div class="flex items-center">
                    <div class="p-2 rounded-lg bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Processed</p>
                      <p class="text-sm font-semibold text-gray-900 dark:text-white"><%= @import.processed_rows %> records</p>
                    </div>
                  </div>
                </div>

                <div class="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-700">
                  <div class="flex items-center">
                    <div class="p-2 rounded-lg bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                      </svg>
                    </div>
                    <div class="ml-3">
                      <p class="text-xs font-medium text-gray-500 dark:text-gray-400">Errors</p>
                      <p class="text-sm font-semibold text-gray-900 dark:text-white"><%= @import.error_count || 0 %></p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Details section -->
          <div class="px-6 py-6">
            <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Import Details</h2>

            <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
              <%= if @import.inserted_at do %>
                <div class="sm:col-span-1">
                  <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Started At</dt>
                  <dd class="mt-1 text-sm text-gray-900 dark:text-white"><%= format_datetime(@import.inserted_at) %></dd>
                </div>
              <% end %>

              <%= if @import.completed_at do %>
                <div class="sm:col-span-1">
                  <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Completed At</dt>
                  <dd class="mt-1 text-sm text-gray-900 dark:text-white"><%= format_datetime(@import.completed_at) %></dd>
                </div>
              <% end %>

              <%= if processing_time(@import) > 0 do %>
                <div class="sm:col-span-2">
                  <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Processing Time</dt>
                  <dd class="mt-1 text-sm text-gray-900 dark:text-white"><%= format_duration(processing_time(@import)) %></dd>
                </div>
              <% end %>
            </dl>
          </div>

          <!-- Errors section if applicable -->
          <%= if @import.error_count && @import.error_count > 0 do %>
          <div class="px-6 py-6 border-t border-gray-100 dark:border-gray-700 bg-red-50 dark:bg-red-900/10">
            <h2 class="text-lg font-semibold text-red-700 dark:text-red-400 mb-4">
              <div class="flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                Errors (<%= @import.error_count %>)
              </div>
            </h2>

            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-red-200 dark:border-red-900/30 overflow-hidden">
              <ul class="divide-y divide-red-100 dark:divide-red-900/30">
                <%= for error <- parse_error_details(@import.error_details) do %>
                  <li class="px-4 py-3 text-sm">
                    <div class="flex items-start">
                      <div class="flex-shrink-0 pt-0.5">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </div>
                      <div class="ml-3">
                        <p class="font-medium text-red-800 dark:text-red-400">Row <%= error["row"] %></p>
                        <p class="text-red-700 dark:text-red-300 break-words"><%= inspect(error["error"]) %></p>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
          <% end %>
        </div>
      </div>

      <!-- Reusable confirmation modal for stopping import -->
      <.import_stop_modal
        show={@show_stop_modal}
        import={@import}
        on_hide="hide_stop_modal"
        on_confirm="confirm_halt_import"
      />
    </div>
    """
  end

  # Helper function for calculating the progress percentage
  defp progress_percentage(import) do
    case import do
      %{total_rows: total, processed_rows: processed}
      when is_number(total) and is_number(processed) and total > 0 ->
        # Calculate percentage and cap it at 100
        percentage = round(processed / total * 100)
        min(percentage, 100)

      _ ->
        0
    end
  end

  # Helper function for formatting datetime
  defp format_datetime(datetime) when is_nil(datetime), do: "-"

  defp format_datetime(datetime) do
    # Convert to IST before formatting
    ist_datetime = datetime |> Util.naive_to_datetime() |> Util.to_ist()

    "#{ist_datetime.year}-#{pad(ist_datetime.month)}-#{pad(ist_datetime.day)} #{pad(ist_datetime.hour)}:#{pad(ist_datetime.minute)}:#{pad(ist_datetime.second)}"
  end

  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"

  # Helper function for progress bar classes
  defp progress_bar_classes("completed"),
    do: "bg-gradient-to-r from-green-500 to-emerald-500 h-3 rounded-full"

  defp progress_bar_classes("failed"),
    do: "bg-gradient-to-r from-red-500 to-rose-500 h-3 rounded-full"

  defp progress_bar_classes(_),
    do: "bg-gradient-to-r from-indigo-500 to-violet-500 h-3 rounded-full animate-pulse"

  # Calculate processing time in seconds
  defp processing_time(%{inserted_at: inserted_at, completed_at: completed_at})
       when not is_nil(inserted_at) and not is_nil(completed_at) do
    # Convert NaiveDateTime to DateTime if needed
    start_time = Util.naive_to_datetime(inserted_at) |> Util.to_ist()
    end_time = Util.naive_to_datetime(completed_at) |> Util.to_ist()

    DateTime.diff(end_time, start_time)
  end

  defp processing_time(%{inserted_at: inserted_at}) when not is_nil(inserted_at) do
    start_time = Util.naive_to_datetime(inserted_at) |> Util.to_ist()
    now_ist = DateTime.utc_now() |> Util.to_ist()

    DateTime.diff(now_ist, start_time)
  end

  defp processing_time(_), do: 0

  # Format duration in seconds to human-readable string
  defp format_duration(seconds) when seconds < 60 do
    "#{seconds} seconds"
  end

  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{minutes} #{pluralize(minutes, "minute")} #{remaining_seconds} #{pluralize(remaining_seconds, "second")}"
  end

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    remaining = rem(seconds, 3600)
    minutes = div(remaining, 60)
    "#{hours} #{pluralize(hours, "hour")} #{minutes} #{pluralize(minutes, "minute")}"
  end

  defp pluralize(1, word), do: word
  defp pluralize(_, word), do: "#{word}s"

  # Status badge (using raw HTML)
  defp status_badge("completed") do
    raw("""
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400">
      <svg class="-ml-0.5 mr-1.5 h-3 w-3 text-green-400 dark:text-green-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Completed
    </span>
    """)
  end

  defp status_badge("processing") do
    raw("""
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400">
      <svg class="-ml-0.5 mr-1.5 h-3 w-3 text-amber-400 dark:text-amber-500 animate-pulse" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Processing
    </span>
    """)
  end

  defp status_badge("pending") do
    raw("""
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400">
      <svg class="-ml-0.5 mr-1.5 h-3 w-3 text-blue-400 dark:text-blue-500 animate-pulse" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Pending
    </span>
    """)
  end

  defp status_badge("failed") do
    raw("""
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-400">
      <svg class="-ml-0.5 mr-1.5 h-3 w-3 text-rose-400 dark:text-rose-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Failed
    </span>
    """)
  end

  defp status_badge("stopped") do
    raw("""
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400">
      <svg class="-ml-0.5 mr-1.5 h-3 w-3 text-orange-400 dark:text-orange-500" fill="currentColor" viewBox="0 0 8 8">
        <circle cx="4" cy="4" r="3" />
      </svg>
      Stopped
    </span>
    """)
  end

  defp status_badge(status) do
    raw("""
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-300">
      #{status}
    </span>
    """)
  end
end
