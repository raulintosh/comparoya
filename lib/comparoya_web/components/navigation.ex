defmodule ComparoyaWeb.Navigation do
  use ComparoyaWeb, :html

  @doc """
  Renders a responsive navigation bar that adapts to mobile, tablet, and desktop.

  ## Examples

      <.responsive_navbar current_user={@current_user} />
  """
  attr :current_user, :map, default: nil

  def responsive_navbar(assigns) do
    ~H"""
    <header class="sticky top-0 flex flex-wrap sm:justify-start sm:flex-nowrap z-50 w-full bg-white border-b border-gray-200 text-sm py-3 sm:py-0">
      <nav
        class="relative max-w-[85rem] w-full mx-auto px-4 sm:flex sm:items-center sm:justify-between sm:px-6 lg:px-8"
        aria-label="Global"
      >
        <div class="flex items-center justify-between">
          <a class="flex-none text-xl font-semibold dark:text-white" href="/" aria-label="Brand">
            <img src="/images/comparoya_logo.svg" width="36" alt="Comparoya" />
          </a>
          <div class="sm:hidden">
            <button
              type="button"
              class="hs-collapse-toggle p-2 inline-flex justify-center items-center gap-2 rounded-md border font-medium bg-white text-gray-700 shadow-sm align-middle hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-white focus:ring-brand transition-all text-sm"
              data-hs-collapse="#navbar-collapse-with-animation"
              aria-controls="navbar-collapse-with-animation"
              aria-label="Toggle navigation"
            >
              <svg
                class="hs-collapse-open:hidden w-4 h-4"
                width="16"
                height="16"
                fill="currentColor"
                viewBox="0 0 16 16"
              >
                <path
                  fill-rule="evenodd"
                  d="M2.5 12a.5.5 0 0 1 .5-.5h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5zm0-4a.5.5 0 0 1 .5-.5h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5zm0-4a.5.5 0 0 1 .5-.5h10a.5.5 0 0 1 0 1H3a.5.5 0 0 1-.5-.5z"
                />
              </svg>
              <svg
                class="hs-collapse-open:block hidden w-4 h-4"
                width="16"
                height="16"
                fill="currentColor"
                viewBox="0 0 16 16"
              >
                <path d="M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z" />
              </svg>
            </button>
          </div>
        </div>
        <div
          id="navbar-collapse-with-animation"
          class="hs-collapse hidden overflow-hidden transition-all duration-300 basis-full grow sm:block"
        >
          <div class="flex flex-col gap-5 mt-5 sm:flex-row sm:items-center sm:justify-end sm:mt-0 sm:ps-5">
            <a class="font-medium text-brand hover:text-brand-600" href="/" aria-current="page">
              Home
            </a>
            <a class="font-medium text-gray-600 hover:text-gray-400" href="#">Features</a>
            <a class="font-medium text-gray-600 hover:text-gray-400" href="#">About</a>
            <a class="font-medium text-gray-600 hover:text-gray-400" href="#">Contact</a>

            <%= if @current_user do %>
              <div class="flex items-center gap-2">
                <%= if Map.get(@current_user, :avatar) do %>
                  <img src={@current_user.avatar} class="h-8 w-8 rounded-full" alt="User avatar" />
                <% end %>
                <span class="text-sm font-medium text-gray-800">
                  {@current_user.name || @current_user.email}
                </span>
                <a
                  href="/logout"
                  class="py-2 px-3 inline-flex justify-center items-center gap-2 rounded-md border font-medium bg-white text-gray-700 shadow-sm align-middle hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-white focus:ring-brand transition-all text-sm"
                >
                  Cerrar Sesión
                </a>
              </div>
            <% else %>
              <a
                href="/auth/google"
                class="py-2 px-3 inline-flex justify-center items-center gap-2 rounded-md border border-transparent font-semibold bg-brand text-white hover:bg-brand-600 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:ring-offset-2 transition-all text-sm"
              >
                Iniciar Sesión con Google
              </a>
            <% end %>
          </div>
        </div>
      </nav>
    </header>
    """
  end
end
