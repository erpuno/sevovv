defmodule Soap.Xsd do
  @moduledoc """
  Provides functions for parsing xsd file
  """

  import SwXml, except: [parse: 1]

  alias Soap.Type

  @spec parse(String.t()) :: {:ok, map()} | {:error, atom()}
  def parse(path) do
    if URI.parse(path).scheme do
      parse_from_url(path)
    else
      parse_from_file(path)
    end
  end

  @spec parse_from_file(String.t()) :: {:ok, map()} | {:error, atom()}
  def parse_from_file(path) do
    case File.read(path) do
      {:ok, xsd} -> parse_xsd(xsd)
      error_response -> error_response
    end
  end

  @spec parse_from_url(String.t()) :: {:ok, map()} | {:error, atom()}
  def parse_from_url(path) do
    case :httpc.request(:get,{path|>:erlang.binary_to_list,[]},
                                 [{:relaxed,true},{:timeout,5000}], []) do
      {:ok, {{_,404,_},_,_}} -> {:error, :not_found}
      {:ok, {{_,200,_},_,body}} -> parse_xsd(body|>:erlang.list_to_binary)
      {:error, reason} -> {:error, reason}
    end
  end

  @spec parse(String.t()) :: {:ok, map()}
  def parse_xsd(xsd) do
    parsed_response = %{
      simple_types: get_simple_types(xsd),
      complex_types: Type.get_complex_types(xsd, "//xs:schema/xs:complexType")
    }

    {:ok, parsed_response}
  end

  @spec get_simple_types(String.t()) :: list()
  def get_simple_types(wsdl) do
    wsdl
    |> xpath(
      ~x"//xs:schema/xs:simpleType"l,
      name: ~x"./@name"s,
      restriction: [
        ~x"./xs:restriction"o,
        base: ~x"./@base"s,
        min_inclusive: ~x"./xs:minInclusive/@value"s,
        max_inclusive: ~x"./xs:maxInclusive/@value"s,
        max_length: ~x"./xs:maxLength/@value"io,
        total_digits: ~x"./xs:totalDigits/@value"io,
        fraction_digits: ~x"./xs:fractionDigits/@value"io,
        pattern: ~x"./xs:pattern/@value"so,
        enumeration: ~x"./xs:enumeration/@value"lso
      ],
      list: [
        ~x"./xs:list"o,
        item_type: ~x"./@itemType"s
      ],
      union: [
        ~x"./xs:union"o,
        types: ~x"./xs:simpleType/xs:restriction/@base"lo
      ]
    )
  end
end
