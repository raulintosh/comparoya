# Test Structure Overview

## Guidelines for Testing Elixir Modules

We will generate test files for all modules and functions currently not having tests within the `/lib` directory, placing them into the `/test` directory maintaining similar sub-directory structure.

### Example Test Module

For `lib/comparoya/accounts.ex`, corresponding test file would be:

- Path: `test/comparoya/accounts_test.exs`

### Basic Test Template
```elixir
defmodule Comparoya.AccountsTest do
  use ExUnit.Case
  alias Comparoya.Accounts

  describe "function_name/arity" do
    test "description of test case" do
      # Arrange

      # Act

      # Assert
    end
  end
end
```

This template provides a basis to expand upon as you flesh out real tests for your application needs, adding more descriptive assertions and setups for varied conditions.