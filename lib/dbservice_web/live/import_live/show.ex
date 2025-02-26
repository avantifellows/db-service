defmodule DbserviceWeb.ImportLive.Show do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    import_record = DataImport.get_import!(id)

    if connected?(socket) do
      # Only set up the timer if the import is still in progress
      if import_record.status in ["pending", "processing"] do
        # Check status every 1 second
        :timer.send_interval(1000, self(), :update_import_status)
      end
    end

    {:ok, assign(socket, import: import_record)}
  end

  @impl true
  def handle_info(:update_import_status, socket) do
    import_record = DataImport.get_import!(socket.assigns.import.id)

    # Stop the timer if import is complete or failed
    if import_record.status in ["completed", "failed"] do
      # The process is completed, we could stop the timer if we had stored its reference
      # But Phoenix automatically cleans up when the LiveView process exits
    end

    {:noreply, assign(socket, import: import_record)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-8 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-3xl font-semibold text-gray-900">Import Details</h1>
      </div>

      <div class="bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <dl class="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
            <div class="sm:col-span-1">
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd class="mt-1 text-sm text-gray-900"><%= @import.status %></dd>
            </div>

            <div class="sm:col-span-1">
              <dt class="text-sm font-medium text-gray-500">Progress</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= @import.processed_rows %>/<%= @import.total_rows %> records

                <div class="w-full bg-gray-200 rounded-full h-2.5 mt-2">
                  <div class="bg-blue-600 h-2.5 rounded-full" style={"width: #{progress_percentage(@import)}%"}></div>
                </div>
              </dd>
            </div>

            <%= if @import.error_count && @import.error_count > 0 do %>
              <div class="sm:col-span-2">
                <dt class="text-sm font-medium text-gray-500">Errors (<%= @import.error_count %>)</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  <div class="mt-2 space-y-2">
                    <%= for error <- @import.error_details || [] do %>
                      <div class="text-red-600">
                        Row <%= error.row %>: <%= error.error %>
                      </div>
                    <% end %>
                  </div>
                </dd>
              </div>
            <% end %>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  # Helper function for calculating the progress percentage
  defp progress_percentage(import) do
    case import do
      %{total_rows: total, processed_rows: processed}
      when is_number(total) and is_number(processed) and total > 0 ->
        round(processed / total * 100)

      _ ->
        0
    end
  end
end
