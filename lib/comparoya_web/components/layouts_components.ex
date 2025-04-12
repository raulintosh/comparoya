defmodule ComparoyaWeb.LayoutComponents do
  use ComparoyaWeb, :html

  @doc """
  Renders a responsive container that adapts to different screen sizes.

  ## Examples

      <.responsive_container>
        Content goes here
      </.responsive_container>
  """
  slot :inner_block, required: true
  attr :class, :string, default: nil

  def responsive_container(assigns) do
    ~H"""
    <div class={["max-w-[85rem] w-full mx-auto px-4 sm:px-6 lg:px-8", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a responsive footer.

  ## Examples

      <.responsive_footer />
  """
  def responsive_footer(assigns) do
    ~H"""
    <footer class="mt-auto w-full py-10 bg-gray-900">
      <.responsive_container>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 text-center md:text-left">
          <div>
            <h4 class="font-semibold text-gray-100">Comparoya</h4>
            <p class="mt-1 text-gray-400">Making comparison shopping easier.</p>
          </div>
          <div>
            <h4 class="font-semibold text-gray-100">Links</h4>
            <div class="mt-3 grid space-y-3">
              <p>
                <a class="inline-flex gap-x-2 text-gray-400 hover:text-gray-200" href="/">Home</a>
              </p>
              <p>
                <a
                  class="inline-flex gap-x-2 text-gray-400 hover:text-gray-200"
                  href="/privacy-policy"
                >
                  Privacy Policy
                </a>
              </p>
              <p>
                <a
                  class="inline-flex gap-x-2 text-gray-400 hover:text-gray-200"
                  href="/terms-of-service"
                >
                  Terms of Service
                </a>
              </p>
            </div>
          </div>
          <div>
            <h4 class="font-semibold text-gray-100">Contact</h4>
            <div class="mt-3 grid space-y-3">
              <p>
                <a
                  class="inline-flex gap-x-2 text-gray-400 hover:text-gray-200"
                  href="mailto:info@comparoya.com"
                >
                  info@comparoya.com
                </a>
              </p>
            </div>
          </div>
        </div>
        <div class="mt-7 text-center">
          <p class="text-gray-500">© {DateTime.utc_now().year} Comparoya. All rights reserved.</p>
        </div>
      </.responsive_container>
    </footer>
    """
  end

  @doc """
  Renders a responsive hero section.

  ## Examples

      <.hero_section>
        <:title>Welcome to Comparoya</:title>
        <:subtitle>Making comparison shopping easier.</:subtitle>
      </.hero_section>
  """
  slot :title, required: true
  slot :subtitle
  slot :actions

  def hero_section(assigns) do
    ~H"""
    <div class="relative overflow-hidden before:absolute before:top-0 before:start-1/2 before:bg-[url('https://preline.co/assets/svg/component/polygon-bg-element.svg')] before:bg-no-repeat before:bg-top before:size-full before:-z-[1] before:transform before:-translate-x-1/2 dark:before:bg-[url('https://preline.co/assets/svg/component/polygon-bg-element-dark.svg')]">
      <.responsive_container>
        <div class="max-w-4xl mx-auto text-center py-10 px-4 sm:px-6 lg:px-8 lg:py-16">
          <div class="mt-5 max-w-2xl">
            <h1 class="block font-bold text-gray-800 text-4xl md:text-5xl lg:text-6xl dark:text-gray-200">
              {render_slot(@title)}
            </h1>
          </div>

          <div :if={@subtitle != []} class="mt-5 max-w-3xl mx-auto">
            <p class="text-lg text-gray-600 dark:text-gray-400">
              {render_slot(@subtitle)}
            </p>
          </div>

          <div :if={@actions != []} class="mt-8 gap-3 flex justify-center">
            {render_slot(@actions)}
          </div>
        </div>
      </.responsive_container>
    </div>
    """
  end

  @doc """
  Renders a responsive card grid.

  ## Examples

      <.card_grid>
        <.card title="Card 1">Content 1</.card>
        <.card title="Card 2">Content 2</.card>
      </.card_grid>
  """
  slot :inner_block, required: true
  attr :columns, :string, default: "md:grid-cols-2 lg:grid-cols-3"

  def card_grid(assigns) do
    ~H"""
    <div class={["grid grid-cols-1 gap-6", @columns]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a responsive card.

  ## Examples

      <.card title="Card Title">
        Card content goes here
      </.card>
  """
  slot :inner_block, required: true
  attr :title, :string, required: true
  attr :class, :string, default: nil

  def card(assigns) do
    ~H"""
    <div class={[
      "group flex flex-col h-full bg-white border border-gray-200 shadow-sm rounded-xl dark:bg-slate-900 dark:border-gray-700 dark:shadow-slate-700/[.7]",
      @class
    ]}>
      <div class="p-4 md:p-6">
        <h3 class="text-xl font-semibold text-gray-800 dark:text-gray-300">
          {@title}
        </h3>
        <div class="mt-3 text-gray-500">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end
end
