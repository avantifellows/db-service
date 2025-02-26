defmodule DbserviceWeb.ImportLive.Index do
  use DbserviceWeb, :live_view
  alias Dbservice.DataImport

  @impl true
  def mount(_params, _session, socket) do
    imports = DataImport.list_imports()
    {:ok, assign(socket, imports: imports)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
    <div class="mt-8 mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-3xl font-semibold text-gray-900">DATA IMPORTS</h1>
      </div>

      <div class="mb-6">
        <%= live_redirect "New Import",
            to: Routes.live_path(@socket, DbserviceWeb.ImportLive.New),
            class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" %>
      </div>

      <div class="flex flex-col">
        <div class="-my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="py-2 align-middle inline-block min-w-full sm:px-6 lg:px-8">
            <div class="shadow overflow-hidden border-b border-gray-200 sm:rounded-lg">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Progress</th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created At</th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for import <- @imports do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= import.type %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= import.status %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= import.processed_rows %>/<%= import.total_rows %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= format_datetime(import.inserted_at) %></td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <%= live_redirect "View",
                            to: Routes.live_path(@socket, DbserviceWeb.ImportLive.Show, import.id),
                            class: "text-blue-600 hover:text-blue-900" %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function for formatting datetime
  defp format_datetime(datetime) do
    "#{datetime.year}-#{pad(datetime.month)}-#{pad(datetime.day)} #{pad(datetime.hour)}:#{pad(datetime.minute)}:#{pad(datetime.second)}"
  end

  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"
end
