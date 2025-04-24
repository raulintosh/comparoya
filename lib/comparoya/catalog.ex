defmodule Comparoya.Catalog do
  @moduledoc """
  The Catalog context.

  This context handles all operations related to the product catalog,
  including categories and subcategories.
  """

  import Ecto.Query, warn: false
  alias Comparoya.Repo
  alias Comparoya.Catalog.{Category, Subcategory}

  @doc """
  Returns the list of categories.

  ## Examples

      iex> list_categories()
      [%Category{}, ...]

  """
  def list_categories do
    Repo.all(Category)
  end

  @doc """
  Returns the list of categories with their subcategories preloaded.

  ## Examples

      iex> list_categories_with_subcategories()
      [%Category{subcategories: [%Subcategory{}, ...]}, ...]

  """
  def list_categories_with_subcategories do
    Repo.all(Category) |> Repo.preload(:subcategories)
  end

  @doc """
  Gets a single category.

  Raises `Ecto.NoResultsError` if the Category does not exist.

  ## Examples

      iex> get_category!(123)
      %Category{}

      iex> get_category!(456)
      ** (Ecto.NoResultsError)

  """
  def get_category!(id), do: Repo.get!(Category, id)

  @doc """
  Gets a single category with its subcategories preloaded.

  Raises `Ecto.NoResultsError` if the Category does not exist.

  ## Examples

      iex> get_category_with_subcategories!(123)
      %Category{subcategories: [%Subcategory{}, ...]}

  """
  def get_category_with_subcategories!(id) do
    Repo.get!(Category, id) |> Repo.preload(:subcategories)
  end

  @doc """
  Creates a category.

  ## Examples

      iex> create_category(%{field: value})
      {:ok, %Category{}}

      iex> create_category(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.

  ## Examples

      iex> update_category(category, %{field: new_value})
      {:ok, %Category{}}

      iex> update_category(category, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category.

  ## Examples

      iex> delete_category(category)
      {:ok, %Category{}}

      iex> delete_category(category)
      {:error, %Ecto.Changeset{}}

  """
  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.

  ## Examples

      iex> change_category(category)
      %Ecto.Changeset{data: %Category{}}

  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  @doc """
  Returns the list of subcategories.

  ## Examples

      iex> list_subcategories()
      [%Subcategory{}, ...]

  """
  def list_subcategories do
    Repo.all(Subcategory)
  end

  @doc """
  Returns the list of subcategories with their category preloaded.

  ## Examples

      iex> list_subcategories_with_category()
      [%Subcategory{category: %Category{}}, ...]

  """
  def list_subcategories_with_category do
    Repo.all(Subcategory) |> Repo.preload(:category)
  end

  @doc """
  Gets a single subcategory.

  Raises `Ecto.NoResultsError` if the Subcategory does not exist.

  ## Examples

      iex> get_subcategory!(123)
      %Subcategory{}

      iex> get_subcategory!(456)
      ** (Ecto.NoResultsError)

  """
  def get_subcategory!(id), do: Repo.get!(Subcategory, id)

  @doc """
  Gets a single subcategory with its category preloaded.

  Raises `Ecto.NoResultsError` if the Subcategory does not exist.

  ## Examples

      iex> get_subcategory_with_category!(123)
      %Subcategory{category: %Category{}}

  """
  def get_subcategory_with_category!(id) do
    Repo.get!(Subcategory, id) |> Repo.preload(:category)
  end

  @doc """
  Creates a subcategory.

  ## Examples

      iex> create_subcategory(%{field: value})
      {:ok, %Subcategory{}}

      iex> create_subcategory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_subcategory(attrs \\ %{}) do
    %Subcategory{}
    |> Subcategory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subcategory.

  ## Examples

      iex> update_subcategory(subcategory, %{field: new_value})
      {:ok, %Subcategory{}}

      iex> update_subcategory(subcategory, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_subcategory(%Subcategory{} = subcategory, attrs) do
    subcategory
    |> Subcategory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a subcategory.

  ## Examples

      iex> delete_subcategory(subcategory)
      {:ok, %Subcategory{}}

      iex> delete_subcategory(subcategory)
      {:error, %Ecto.Changeset{}}

  """
  def delete_subcategory(%Subcategory{} = subcategory) do
    Repo.delete(subcategory)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subcategory changes.

  ## Examples

      iex> change_subcategory(subcategory)
      %Ecto.Changeset{data: %Subcategory{}}

  """
  def change_subcategory(%Subcategory{} = subcategory, attrs \\ %{}) do
    Subcategory.changeset(subcategory, attrs)
  end

  @doc """
  Returns the list of subcategories for a specific category.

  ## Examples

      iex> list_subcategories_by_category(category_id)
      [%Subcategory{}, ...]

  """
  def list_subcategories_by_category(category_id) do
    Subcategory
    |> where([s], s.category_id == ^category_id)
    |> Repo.all()
  end

  @doc """
  Searches for categories by description.

  ## Examples

      iex> search_categories("food")
      [%Category{}, ...]

  """
  def search_categories(query) do
    wildcard_query = "%#{query}%"

    Category
    |> where([c], ilike(c.description, ^wildcard_query))
    |> Repo.all()
  end

  @doc """
  Searches for subcategories by description.

  ## Examples

      iex> search_subcategories("fruit")
      [%Subcategory{}, ...]

  """
  def search_subcategories(query) do
    wildcard_query = "%#{query}%"

    Subcategory
    |> where([s], ilike(s.description, ^wildcard_query))
    |> Repo.all()
  end
end
