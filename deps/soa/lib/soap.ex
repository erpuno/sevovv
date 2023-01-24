defmodule Soap do
  alias Soap.{Request, Response, Wsdl}

  @spec init_model(String.t(), :file | :url) :: {:ok, map()}
  def init_model(path, type \\ :file)
  def init_model(path, :file), do: Wsdl.parse_from_file(path)
  def init_model(path, :url), do: Wsdl.parse_from_url(path)

  @spec call(wsdl :: map(), operation :: String.t(), params :: map(), headers :: any(), opts :: any()) :: any()
  def call(wsdl, operation, params, headers \\ [], opts \\ []) do
    wsdl
    |> validate_operation(operation)
    |> Request.call(operation, params, headers, opts)
    |> handle_response
  end

  @spec operations(map()) :: nonempty_list(String.t())
  def operations(wsdl) do
    wsdl.operations
  end

  defp handle_response({:ok, {{_,status,_},_,body}}), do: {:ok, %Response{status_code: status, body: :unicode.characters_to_binary(body)}}
  defp handle_response({:error, reason}), do: {:error, reason}

  defp validate_operation(wsdl, operation) do
    case valid_operation?(wsdl, operation) do
      false -> raise OperationError, operation
      true -> wsdl
    end
  end

  defp valid_operation?(wsdl, operation) do
    Enum.any?(wsdl[:operations], &(&1[:name] == operation))
  end
end
