defmodule Comparoya.Catalog.Scraper do
  alias Comparoya.Catalog
  alias Comparoya.Catalog.{Subcategory, ProductReference}
  alias Comparoya.Invoices.BusinessEntity
  alias Comparoya.Repo
  import Ecto.Query

  require Logger
  alias Phoenix.PubSub

  @topic "scraper:updates"

  @doc """
  Scrapes products from a subcategory URL and stores them in the database.
  """
  def scrape_subcategory(subcategory_id) do
    subcategory = Repo.get!(Subcategory, subcategory_id) |> Repo.preload(:category)

    if subcategory.category.business_entities_id == nil do
      message = "Subcategory's category has no business entity"
      Logger.error("Scraping error: #{message}")
      broadcast_update(:error, %{subcategory_id: subcategory_id, message: message})
      {:error, message}
    else
      business_entity = Repo.get!(BusinessEntity, subcategory.category.business_entities_id)

      Logger.info("Scraping subcategory: #{subcategory.description} from #{subcategory.path}")

      broadcast_update(:start, %{
        subcategory_id: subcategory_id,
        subcategory_name: subcategory.description,
        business_entity: business_entity.slug,
        url: subcategory.path
      })

      # Fetch the HTML content with retry logic
      case fetch_with_retry(subcategory.path, 3) do
        {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
        when status_code in 200..299 ->
          Logger.debug(
            "Successfully fetched HTML from #{subcategory.path} with status code: #{status_code}"
          )

          # Log the first 500 characters of the body for debugging
          body_preview =
            if String.length(body) > 500, do: String.slice(body, 0, 500) <> "...", else: body

          Logger.debug("Response body preview: #{body_preview}")

          # Parse the HTML
          case Floki.parse_document(body) do
            {:ok, document} ->
              Logger.debug("Successfully parsed HTML document")

              broadcast_update(:progress, %{
                subcategory_id: subcategory_id,
                subcategory_name: subcategory.description,
                message: "Parsing HTML and extracting products"
              })

              # Extract products
              products = extract_products(document)

              Logger.info(
                "Extracted #{length(products)} products from #{subcategory.description}"
              )

              broadcast_update(:progress, %{
                subcategory_id: subcategory_id,
                subcategory_name: subcategory.description,
                products_count: length(products),
                message: "Extracted #{length(products)} products"
              })

              # Store products in database
              Logger.info("Storing #{length(products)} products in database")

              broadcast_update(:progress, %{
                subcategory_id: subcategory_id,
                subcategory_name: subcategory.description,
                message: "Storing products in database"
              })

              results =
                Enum.map(products, fn product ->
                  result =
                    ProductReference.find_or_create(%{
                      name: product.name,
                      barcode: product.barcode,
                      internal_code: product.code,
                      subcategory_id: subcategory.id,
                      business_entity_id: business_entity.id
                    })

                  # Log individual product results
                  case result do
                    {:ok, product_ref} ->
                      Logger.debug(
                        "Stored product: #{product_ref.name}, barcode: #{product_ref.barcode}"
                      )

                    {:error, changeset} ->
                      Logger.warn(
                        "Failed to store product: #{product.name}, errors: #{inspect(changeset.errors)}"
                      )
                  end

                  result
                end)

              # Handle pagination if needed
              next_page = extract_next_page_url(document, subcategory.path)

              pagination_results =
                if next_page do
                  Logger.info("Found next page: #{next_page}, continuing scraping")

                  broadcast_update(:progress, %{
                    subcategory_id: subcategory_id,
                    subcategory_name: subcategory.description,
                    message: "Found next page, continuing scraping"
                  })

                  scrape_next_page(next_page, subcategory, business_entity)
                else
                  Logger.info("No more pages to scrape for #{subcategory.description}")
                  []
                end

              successful = Enum.count(results, fn {status, _} -> status == :ok end)
              failed = length(results) - successful
              total_successful = successful + (pagination_results[:count] || 0)

              Logger.info(
                "Scraped #{length(products)} products from #{subcategory.description}, successfully stored #{successful}, failed #{failed}"
              )

              broadcast_update(:complete, %{
                subcategory_id: subcategory_id,
                subcategory_name: subcategory.description,
                products_count: length(products),
                successful: successful,
                failed: failed,
                total_successful: total_successful,
                message: "Completed scraping #{subcategory.description}"
              })

              {:ok, total_successful}

            {:error, error} ->
              message = "Failed to parse HTML document: #{inspect(error)}"
              Logger.error(message)

              broadcast_update(:error, %{
                subcategory_id: subcategory_id,
                subcategory_name: subcategory.description,
                message: message
              })

              {:error, message}
          end

        {:ok, %HTTPoison.Response{status_code: status_code}} ->
          message = "Failed to fetch page: HTTP #{status_code}"
          Logger.error(message)

          broadcast_update(:error, %{
            subcategory_id: subcategory_id,
            subcategory_name: subcategory.description,
            message: message
          })

          {:error, message}

        {:error, %HTTPoison.Error{reason: reason}} ->
          message = "Failed to fetch page: #{reason}"
          Logger.error(message)

          broadcast_update(:error, %{
            subcategory_id: subcategory_id,
            subcategory_name: subcategory.description,
            message: message
          })

          {:error, message}
      end
    end
  end

  # Extract product information from the HTML
  defp extract_products(document) do
    # Find all product-item elements
    Floki.find(document, ".product-item")
    |> Enum.map(fn product_element ->
      # Find the picture-link element and get its href attribute
      picture_link = Floki.find(product_element, ".picture-link")

      case Floki.attribute(picture_link, "href") do
        [product_url | _] ->
          # Navigate to the product page with retry logic
          case fetch_with_retry(product_url, 2) do
            {:ok, %HTTPoison.Response{status_code: status_code, body: product_body}}
            when status_code in 200..299 ->
              case Floki.parse_document(product_body) do
                {:ok, product_document} ->
                  # Extract product name from h1 with class="productname"
                  name =
                    Floki.find(product_document, "h1.productname")
                    |> Floki.text()
                    |> String.trim()

                  # Extract barcode from element with class="sku"
                  barcode =
                    Floki.find(product_document, ".sku")
                    |> Floki.text()
                    |> String.trim()

                  # Extract internal code if available (keeping existing logic)
                  code_element = Floki.find(product_element, ".product-sku")

                  code =
                    if Enum.empty?(code_element) do
                      nil
                    else
                      Floki.text(code_element) |> String.trim()
                    end

                  %{
                    name: name,
                    barcode: barcode,
                    code: code
                  }

                {:error, error} ->
                  Logger.error(
                    "Failed to parse product page: #{inspect(error)} for URL #{product_url}"
                  )

                  nil
              end

            {:ok, %HTTPoison.Response{status_code: status_code}} ->
              Logger.error(
                "Failed to fetch product page: HTTP #{status_code} for URL #{product_url}"
              )

              nil

            {:error, %HTTPoison.Error{reason: reason}} ->
              Logger.error("Failed to fetch product page: #{reason} for URL #{product_url}")
              nil
          end

        [] ->
          Logger.warn("No picture-link href found for product item")
          nil
      end
    end)
    # Remove nil entries (failed requests)
    |> Enum.reject(&is_nil/1)
  end

  # Extract the URL for the next page
  defp extract_next_page_url(document, base_url) do
    # Find the next page link
    next_link = Floki.find(document, ".pagination .next a")

    case next_link do
      [] ->
        nil

      [link | _] ->
        href = Floki.attribute(link, "href") |> List.first()

        if href do
          if String.starts_with?(href, "http") do
            href
          else
            URI.merge(base_url, href) |> to_string()
          end
        else
          nil
        end
    end
  end

  # Scrape the next page
  defp scrape_next_page(url, subcategory, business_entity) do
    Logger.info("Scraping next page: #{url}")

    broadcast_update(:progress, %{
      subcategory_id: subcategory.id,
      subcategory_name: subcategory.description,
      message: "Scraping next page: #{url}"
    })

    case fetch_with_retry(url, 3) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 200..299 ->
        case Floki.parse_document(body) do
          {:ok, document} ->
            products = extract_products(document)
            Logger.info("Extracted #{length(products)} products from next page")

            broadcast_update(:progress, %{
              subcategory_id: subcategory.id,
              subcategory_name: subcategory.description,
              products_count: length(products),
              message: "Extracted #{length(products)} products from next page"
            })

            results =
              Enum.map(products, fn product ->
                ProductReference.find_or_create(%{
                  name: product.name,
                  barcode: product.barcode,
                  internal_code: product.code,
                  subcategory_id: subcategory.id,
                  business_entity_id: business_entity.id
                })
              end)

            next_page = extract_next_page_url(document, url)

            pagination_results =
              if next_page do
                scrape_next_page(next_page, subcategory, business_entity)
              else
                []
              end

            successful = Enum.count(results, fn {status, _} -> status == :ok end)
            failed = length(results) - successful

            Logger.info(
              "Successfully stored #{successful} products from next page, failed #{failed}"
            )

            %{count: successful + (pagination_results[:count] || 0)}

          {:error, error} ->
            Logger.error("Failed to parse HTML document for next page: #{inspect(error)}")
            %{count: 0}
        end

      _ ->
        %{count: 0}
    end
  end

  @doc """
  Scrapes all subcategories for a given business entity.
  """
  def scrape_all_subcategories(business_entity_id) do
    business_entity = Repo.get!(BusinessEntity, business_entity_id)

    Logger.info(
      "Starting to scrape all subcategories for business entity: #{business_entity.slug}"
    )

    broadcast_update(:start_all, %{
      business_entity_id: business_entity_id,
      business_entity_name: business_entity.slug,
      message: "Starting to scrape all subcategories"
    })

    query =
      from c in Catalog.Category,
        where: c.business_entities_id == ^business_entity_id,
        preload: [:subcategories]

    categories = Repo.all(query)

    Logger.info(
      "Found #{length(categories)} categories with #{Enum.sum(Enum.map(categories, fn c -> length(c.subcategories) end))} subcategories"
    )

    results =
      Enum.flat_map(categories, fn category ->
        Logger.info(
          "Processing category: #{category.description} with #{length(category.subcategories)} subcategories"
        )

        broadcast_update(:progress_all, %{
          business_entity_id: business_entity_id,
          business_entity_name: business_entity.slug,
          category_name: category.description,
          subcategories_count: length(category.subcategories),
          message: "Processing category: #{category.description}"
        })

        Enum.map(category.subcategories, fn subcategory ->
          case scrape_subcategory(subcategory.id) do
            {:ok, count} -> {subcategory.description, count}
            {:error, reason} -> {subcategory.description, reason}
          end
        end)
      end)

    successful_count = Enum.count(results, fn {_, result} -> is_integer(result) end)

    total_products =
      Enum.sum(
        Enum.map(results, fn {_, result} -> if is_integer(result), do: result, else: 0 end)
      )

    Logger.info(
      "Completed scraping all subcategories. Successfully scraped #{successful_count}/#{length(results)} subcategories with #{total_products} total products"
    )

    broadcast_update(:complete_all, %{
      business_entity_id: business_entity_id,
      business_entity_name: business_entity.slug,
      subcategories_count: length(results),
      successful_count: successful_count,
      total_products: total_products,
      message: "Completed scraping all subcategories"
    })

    {:ok, results}
  end

  # Broadcast updates to PubSub
  defp broadcast_update(event_type, payload) do
    PubSub.broadcast(Comparoya.PubSub, @topic, {event_type, payload})
  end

  # Fetch with retry logic
  defp fetch_with_retry(url, max_retries, current_retry \\ 0) do
    # Modern Firefox browser user agent
    headers = [
      {"User-Agent",
       "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0"},
      {"Accept",
       "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"},
      {"Accept-Language", "en-US,en;q=0.5"},
      {"Accept-Encoding", "gzip, deflate, br"},
      {"Connection", "keep-alive"},
      {"Upgrade-Insecure-Requests", "1"},
      {"Sec-Fetch-Dest", "document"},
      {"Sec-Fetch-Mode", "navigate"},
      {"Sec-Fetch-Site", "none"},
      {"Sec-Fetch-User", "?1"},
      {"Cache-Control", "max-age=0"}
    ]

    # Increase timeouts to 60 seconds and follow redirects
    case HTTPoison.get(url, headers,
           timeout: 60_000,
           recv_timeout: 60_000,
           follow_redirect: true,
           max_redirects: 5,
           hackney: [pool: false]
         ) do
      {:ok, %HTTPoison.Response{status_code: status_code} = response} = success
      when status_code in 200..299 ->
        Logger.debug("Successfully fetched URL: #{url} with status code: #{status_code}")
        success

      {:ok, %HTTPoison.Response{status_code: status_code} = response} ->
        Logger.error("Failed to fetch URL: #{url} with status code: #{status_code}")

        if current_retry < max_retries do
          # Log retry attempt
          Logger.warn(
            "Retry #{current_retry + 1}/#{max_retries} for URL #{url} after HTTP status: #{status_code}"
          )

          # Longer exponential backoff: 5s, 10s, 20s, etc.
          # Convert to integer to avoid :timeout_value error
          sleep_time = trunc(5000 * :math.pow(2, current_retry))
          :timer.sleep(sleep_time)
          fetch_with_retry(url, max_retries, current_retry + 1)
        else
          {:ok, response}
        end

      {:error, %HTTPoison.Error{reason: reason}} = error ->
        Logger.error("HTTP request error for URL: #{url}, reason: #{inspect(reason)}")

        if current_retry < max_retries do
          # Log retry attempt
          Logger.warn(
            "Retry #{current_retry + 1}/#{max_retries} for URL #{url} after error: #{inspect(reason)}"
          )

          # Longer exponential backoff: 5s, 10s, 20s, etc.
          # Convert to integer to avoid :timeout_value error
          sleep_time = trunc(5000 * :math.pow(2, current_retry))
          :timer.sleep(sleep_time)
          fetch_with_retry(url, max_retries, current_retry + 1)
        else
          error
        end
    end
  end
end
