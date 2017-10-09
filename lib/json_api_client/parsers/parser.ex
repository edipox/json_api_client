defmodule JsonApiClient.Parsers.Parser do
  @moduledoc """
  Parses a JSON API HTTP Response
  """

  alias JsonApiClient.{Document}
  alias JsonApiClient.Parsers.{FieldValidation, JsonApiProtocol}

  def parse(map, protocol) do
    field_value(:Document, protocol, ensure_jsonapi_field_exist(map))
  end

  defp field_value(_, _, nil), do: {:ok, nil}

  defp field_value(name, %{array: true} = field_definition, value) when is_list(value) do
    Enum.reduce_while(Enum.reverse(value), {:ok, []}, fn(entry, {result, acc}) ->
      case field_value(name, Map.put(field_definition, :array, false), entry) do
        {:error, error} -> {:halt, {:error, error}}
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
      end
    end)
  end

  defp field_value(name, %{array: true}, value) do
    {:error, "The filed '#{name}' must be an array."}
  end

  defp field_value(name, _, value) when is_list(value) do
    {:error, "The filed '#{name}' cannot be an array."}
  end

  defp field_value(_, %{representation: :object}, %{} = value) do
    {:ok, Map.new(value, fn {k, v} -> {String.to_atom(k), v} end)}
  end

  defp field_value(name, %{representation: :object}, _) do
    {:error, "The filed '#{name}' must be an object."}
  end

  defp field_value(name, %{representation: representation, fields: fields} = field_definition, data) do
    case FieldValidation.valid?(name, field_definition, data) do
      {:ok} ->
        case compute_values(fields, data) do
          {:error, error} -> {:error, error}
          values  -> {:ok, struct(representation, values)}
        end
      error -> error
    end
  end

  defp field_value(name, _, value) do
    {:ok, value}
  end

  def compute_values(fields, data) do
    Enum.reduce_while(fields, %{}, fn({k, definition}, acc) ->
      case field_value(k, definition, data[to_string(k)]) do
        {:error, error} -> {:halt, {:error, error}}
        {:ok, value} -> {:cont, Map.put(acc, k, value)}
      end
    end)
  end

  defp ensure_jsonapi_field_exist(map) do
    Map.put_new(map, "jsonapi", %{"version" => "1.0", "meta" => %{}})
  end
end

