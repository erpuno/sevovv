defmodule XmlGen do

  defmacrop is_blank_attrs(attrs) do
    quote do: is_blank_map(unquote(attrs)) or is_blank_list(unquote(attrs))
  end

  defmacrop is_blank_list(list) do
    quote do: is_nil(unquote(list)) or (is_list(unquote(list)) and length(unquote(list)) == 0)
  end

  defmacrop is_blank_map(map) do
    quote do: is_nil(unquote(map)) or (is_map(unquote(map)) and map_size(unquote(map)) == 0)
  end

  def document(elements), do: [:xml_decl | elements_with_prolog(elements) |> List.wrap]
  def document(name, attrs_or_content), do: [:xml_decl | [element(name, attrs_or_content)]]
  def document(name, attrs, content), do: [:xml_decl | [element(name, attrs, content)]]

  def element(name) when is_bitstring(name), do: element({nil, nil, name})
  def element(name) when is_bitstring(name) or is_atom(name), do: element({name})
  def element(list) when is_list(list), do: Enum.map(list, &element/1)
  def element({name}), do: element({name, nil, nil})
  def element({name, attrs}) when is_map(attrs), do: element({name, attrs, nil})
  def element({name, content}), do: element({name, nil, content})
  def element({name, attrs, content}) when is_list(content), do: {name, attrs, Enum.map(content, &element/1)}
  def element({name, attrs, content}), do: {name, attrs, content}
  def element(name, attrs) when is_map(attrs), do: element({name, attrs, nil})
  def element(name, content), do: element({name, nil, content})
  def element(name, attrs, content), do: element({name, attrs, content})

  def doctype(name, [{:system, system_identifier}]), do: {:doctype, {:system, name, system_identifier}}
  def doctype(name, [{:public, [public_identifier, system_identifier]}]), do: {:doctype, {:public, name, public_identifier, system_identifier}}

  def generate(any, options \\ []), do: format(any, 0, options) |> IO.chardata_to_string

  defp format(:xml_decl, 0, options) do
    encoding = Keyword.get(options, :encoding, "UTF-8")
    ~s|<?xml version="1.0" encoding="#{encoding}"?>|
  end

  defp format({:doctype, {:system, name, system}}, 0, _options), do: ['<!DOCTYPE ', to_string(name), ' SYSTEM "', to_string(system), '">']
  defp format({:doctype, {:public, name, public, system}}, 0, _options), do: ['<!DOCTYPE ', to_string(name), ' PUBLIC "', to_string(public), '" "', to_string(system), '">']
  defp format(string, level, options) when is_bitstring(string), do: format({nil, nil, string}, level, options)
  defp format(list, level, options) when is_list(list) do
    formatter = formatter(options)
    list |> Enum.map(&format(&1, level, options)) |> Enum.intersperse(formatter.line_break())
  end

  defp format({nil, nil, name}, level, options) when is_bitstring(name), do: [indent(level, options), to_string(name)]
  defp format({name, attrs, content}, level, options) when is_blank_attrs(attrs) and is_blank_list(content), do: [indent(level, options), '<', to_string(name), '/>']
  defp format({name, attrs, content}, level, options) when is_blank_list(content), do: [indent(level, options), '<', to_string(name), ' ', format_attributes(attrs), '/>']
  defp format({name, attrs, content}, level, options) when is_blank_attrs(attrs) and not is_list(content), do: [indent(level, options), '<', to_string(name), '>', format_content(content, level+1, options), '</', to_string(name), '>']
  defp format({name, attrs, content}, level, options) when is_blank_attrs(attrs) and is_list(content) do
    format_char = formatter(options).line_break()
    [indent(level, options), '<', to_string(name), '>', format_content(content, level+1, options), format_char, indent(level, options), '</', to_string(name), '>']
  end

  defp format({name, attrs, content}, level, options) when not is_blank_attrs(attrs) and not is_list(content),
    do: [indent(level, options), '<', to_string(name), ' ', format_attributes(attrs), '>', format_content(content, level+1, options), '</', to_string(name), '>']

  defp format({name, attrs, content}, level, options) when not is_blank_attrs(attrs) and is_list(content) do
    format_char = formatter(options).line_break()
    [indent(level, options), '<', to_string(name), ' ', format_attributes(attrs), '>', format_content(content, level+1, options), format_char, indent(level, options), '</', to_string(name), '>']
  end

  defp elements_with_prolog([first | rest]) when length(rest) > 0, do: [first_element(first) |element(rest)]
  defp elements_with_prolog(element_spec), do: element(element_spec)

  defp first_element({:doctype, args} = doctype_decl) when is_tuple(args), do: doctype_decl
  defp first_element(element_spec), do: element(element_spec)

  defp formatter(options) do
    case Keyword.get(options, :format) do
      :none -> XmlGen.Format.None
      _     -> XmlGen.Format.Indented
    end
  end

  defp format_content(children, level, options) when is_list(children) do
    format_char = formatter(options).line_break()
    [format_char, Enum.map_join(children, format_char, &format(&1, level, options))]
  end

  defp format_content(content, _level, _options), do: escape(content)
  defp format_attributes(attrs), do: Enum.map_join(attrs, " ", fn {name,value} -> [to_string(name), '=', quote_attribute_value(value)] end)

  defp indent(level, options) do
    formatter = formatter(options)
    formatter.indentation(level, options)
  end

  defp quote_attribute_value(val) when not is_bitstring(val),
    do: quote_attribute_value(to_string(val))

  defp quote_attribute_value(val) do
    double = String.contains?(val, ~s|"|)
    single = String.contains?(val, "'")
    escaped = escape(val)

    cond do
      double && single ->
        escaped |> String.replace("\"", "&quot;") |> quote_attribute_value
      double -> "'#{escaped}'"
      true -> ~s|"#{escaped}"|
    end
  end

  defp escape({:cdata, data}) do
    ["<![CDATA[", data, "]]>"]
  end

  defp escape(data) when not is_bitstring(data),
    do: escape(to_string(data))

  defp escape(string) do
    string
    |> String.replace(">", "&gt;")
    |> String.replace("<", "&lt;")
    |> String.replace(~s|"|, "&quot;")
    |> String.replace("'", "&apos;")
    |> replace_ampersand
  end

  defp replace_ampersand(string) do
    Regex.replace(~r/&(?!(lt|gt|quot|apos|amp);)/, string, "&amp;")
  end
end

defmodule XmlGen.Format.Indented do
  def indentation(level, options) do
    whitespace = Keyword.get(options, :whitespace, "  ")

    String.duplicate(whitespace, level)
  end

  def line_break(), do: "\n"
end

defmodule XmlGen.Format.None do
  def indentation(_level, _options), do: ""
  def line_break(), do: ""
end
