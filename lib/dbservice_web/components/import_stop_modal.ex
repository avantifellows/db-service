defmodule DbserviceWeb.Components.ImportStopModal do
  @moduledoc """
  A reusable Phoenix LiveView component that renders a confirmation modal for stopping data imports.

  This component provides a consistent user interface for confirming the action of stopping
  an import process across different pages in the application. It displays import progress
  information and warns users about the consequences of stopping an import.

  The modal includes:
  - Current import progress with percentage completion
  - Warning about data loss and the need to restart
  - Cancel and confirm action buttons
  - Responsive design with proper accessibility features

  ## Usage

  This component is designed to be used in LiveView pages that manage import operations,
  such as the import index and show pages.
  """
  use Phoenix.Component

  @doc """
  Renders a confirmation modal for stopping an import.

  ## Attributes

    * `show` - boolean, whether to show the modal
    * `import` - the import record to display information for
    * `on_hide` - event name to trigger when hiding the modal
    * `on_confirm` - event name to trigger when confirming the action

  ## Examples

      <.import_stop_modal
        show={@show_stop_modal}
        import={@selected_import}
        on_hide="hide_stop_modal"
        on_confirm="confirm_halt_import"
      />
  """
  attr :show, :boolean, required: true
  attr :import, :map, required: true
  attr :on_hide, :string, required: true
  attr :on_confirm, :string, required: true

  def import_stop_modal(assigns) do
    ~H"""
    <%= if @show and @import do %>
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <!-- Backdrop overlay with better animation -->
      <div class="fixed inset-0 bg-black/60 backdrop-blur-sm transition-all duration-300" phx-click={@on_hide}></div>

      <!-- Modal content with better positioning -->
      <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
        <div class="relative bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-lg transform transition-all duration-300 scale-100">

          <!-- Modal header with improved styling -->
          <div class="px-8 py-6 border-b border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <div class="flex items-center">
                <div class="flex-shrink-0 w-10 h-10 mx-auto flex items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
                  <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-red-600 dark:text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <h3 class="text-xl font-bold text-gray-900 dark:text-white">
                    Stop Import
                  </h3>
                  <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                    This action cannot be undone
                  </p>
                </div>
              </div>
              <button
                phx-click={@on_hide}
                class="ml-4 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Modal body with better spacing -->
          <div class="px-8 py-6">
            <div class="space-y-4">
              <p class="text-base text-gray-700 dark:text-gray-300 leading-relaxed">
                Are you sure you want to stop this import process? All progress will be lost and you'll need to restart the import from the beginning.
              </p>

              <!-- Progress info card with improved design -->
              <div class="bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/20 dark:to-orange-900/20 rounded-xl p-4 border border-amber-200 dark:border-amber-800">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <svg class="w-5 h-5 text-amber-600 dark:text-amber-400 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h4 class="text-sm font-semibold text-amber-800 dark:text-amber-200">
                      Current Progress
                    </h4>
                    <p class="text-sm text-amber-700 dark:text-amber-300 mt-1">
                      <span class="font-medium"><%= @import.processed_rows %></span> of
                      <span class="font-medium"><%= @import.total_rows %></span> records processed
                      (<%= calculate_percentage(@import.processed_rows, @import.total_rows) %>% complete)
                    </p>
                  </div>
                </div>
              </div>

              <!-- Impact warning -->
              <div class="bg-red-50 dark:bg-red-900/20 rounded-xl p-4 border border-red-200 dark:border-red-800">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <svg class="w-5 h-5 text-red-600 dark:text-red-400 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div class="ml-3">
                    <h4 class="text-sm font-semibold text-red-800 dark:text-red-200">
                      Impact
                    </h4>
                    <ul class="text-sm text-red-700 dark:text-red-300 mt-1 space-y-1">
                      <li>• Import will be marked as "Stopped"</li>
                      <li>• Processed data will be retained</li>
                      <li>• You'll need to create a new import to continue</li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Modal footer with improved button design -->
          <div class="px-8 py-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/50 rounded-b-2xl">
            <div class="flex justify-center gap-4">
              <button
              phx-click={@on_hide}
              class="inline-flex items-center px-6 py-3 text-sm font-medium rounded-xl text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 dark:bg-gray-700 dark:text-gray-300 dark:border-gray-600 dark:hover:bg-gray-600 dark:hover:border-gray-500 transition-all duration-200 shadow-sm">
              <svg class="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
              Cancel
              </button>
              <button
              phx-click={@on_confirm}
              class="inline-flex items-center px-6 py-3 text-sm font-medium rounded-xl text-white bg-gradient-to-r from-red-600 to-red-700 border border-transparent hover:from-red-700 hover:to-red-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:scale-105"
              >
              <svg
              class="w-4 h-4 mr-2"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
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
              Stop Import
              </button>

            </div>
          </div>
        </div>
      </div>
    </div>
    <% end %>
    """
  end

  # Helper function for calculating percentage
  defp calculate_percentage(processed, total) when total > 0 do
    round(processed / total * 100)
  end

  defp calculate_percentage(_, _), do: 0
end
