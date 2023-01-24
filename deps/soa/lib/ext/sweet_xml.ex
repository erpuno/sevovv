defmodule SwXpath do

  defmodule Priv do
    @moduledoc false
    @doc false
    def self_val(val), do: val
  end

  defstruct path: ".",
    is_value: true,
    is_list: false,
    is_keyword: false,
    is_optional: false,
    cast_to: false,
    transform_fun: &(Priv.self_val/1),
    namespaces: []
end

defmodule SwXml do
  require Record

  Record.defrecord :xmlDecl, Record.extract(:xmlDecl, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlAttribute, Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlNamespace, Record.extract(:xmlNamespace, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlNsNode, Record.extract(:xmlNsNode, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlComment, Record.extract(:xmlComment, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlPI, Record.extract(:xmlPI, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlDocument, Record.extract(:xmlDocument, from_lib: "xmerl/include/xmerl.hrl")
  Record.defrecord :xmlObj, Record.extract(:xmlObj, from_lib: "xmerl/include/xmerl.hrl")

  def sigil_x(path, modifiers \\ '') do
    %SwXpath{
      path: String.to_charlist(path),
      is_value: not(?e in modifiers),
      is_list: ?l in modifiers,
      is_keyword: ?k in modifiers,
      is_optional: ?o in modifiers,
      cast_to: cond do
        ?s in modifiers -> :string
        ?S in modifiers -> :soft_string
        ?i in modifiers -> :integer
        ?I in modifiers -> :soft_integer
        ?f in modifiers -> :float
        ?F in modifiers -> :soft_float
        :otherwise -> false
      end
    }
  end

  defp continuation_opts(enum, waiter \\ nil) do
    [{
       :continuation_fun,
       fn xcont, xexc, xstate ->
         case :xmerl_scan.cont_state(xstate).({:cont, []}) do
       {:halted, _acc} ->
         xexc.(xstate)
           {:suspended, bin, cont}->
             case waiter do
               nil -> :ok
               {parent, ref} ->
                 send(parent, {:wait, ref}) # continuation behaviour, pause and wait stream decision
                 receive do
                   {:continue, ^ref} -> # stream continuation fun has been called: parse to find more elements
                     :ok
                   {:halt, ^ref} -> # stream halted: halt the underlying stream and exit parsing process
                     cont.({:halt, []})
                     exit(:normal)
                 end
             end
             xcont.(bin, :xmerl_scan.cont_state(cont, xstate))
           {:done, _} -> xexc.(xstate)
         end
       end,
       &Enumerable.reduce(split_by_whitespace(enum), &1, fn bin, _ -> {:suspend, bin} end)
     },
     {
       :close_fun,
       fn xstate -> # make sure the XML end halts the binary stream (if more bytes are available after XML)
         :xmerl_scan.cont_state(xstate).({:halt,[]})
         xstate
       end
     }]
  end

  defp split_by_whitespace(enum) do
    reducer = fn
      :last, prev ->
        {[:erlang.binary_to_list(prev)], :done}
      bin, prev ->
        bin = if (prev === ""), do: bin, else: IO.iodata_to_binary([prev, bin])
        case split_last_whitespace(bin) do
          :white_bin -> {[], bin}
          {head, tail} -> {[:erlang.binary_to_list(head)], tail}
        end
    end

    Stream.concat(enum, [:last]) |> Stream.transform("", reducer)
  end

  defp split_last_whitespace(bin), do: split_last_whitespace(byte_size(bin) - 1, bin)
  defp split_last_whitespace(0, _), do: :white_bin
  defp split_last_whitespace(size, bin) do
    case bin do
      <<_::binary - size(size), h>> <> tail when h == ?\s or h == ?\n or h == ?\r or h == ?\t ->
        {head, _} = :erlang.split_binary(bin, size + 1)
        {head, tail}
      _ ->
        split_last_whitespace(size - 1, bin)
    end
  end

 def parse(doc), do: parse(doc, [])
  def parse(doc, options) when is_binary(doc) do
    doc |> :erlang.binary_to_list |> parse(options)
  end
  def parse([c | _] = doc, options) when is_integer(c) do
    {parsed_doc, _} = :xmerl_scan.string(doc, options)
    parsed_doc
  end
  def parse(doc_enum, options) do
    {parsed_doc, _} = :xmerl_scan.string('', options ++ continuation_opts(doc_enum))
    parsed_doc
  end

  def xpath(parent, spec) when not is_tuple(parent) do
    parent |> parse |> xpath(spec)
  end

  def xpath(parent, %SwXpath{is_list: true, is_value: true, cast_to: cast, is_optional: is_opt?} = spec) do
    get_current_entities(parent, spec) |> Enum.map(&(_value(&1)) |> to_cast(cast,is_opt?)) |> spec.transform_fun.()
  end

  def xpath(parent, %SwXpath{is_list: true, is_value: false} = spec) do
    get_current_entities(parent, spec) |> spec.transform_fun.()
  end

  def xpath(parent, %SwXpath{is_list: false, is_value: true, cast_to: string_type, is_optional: is_opt?} = spec) 
    when string_type in [:string,:soft_string] do
    spec = %SwXpath{spec | is_list: true}
    get_current_entities(parent, spec)
    |> Enum.map(&(_value(&1) |> to_cast(string_type, is_opt?)))
    |> Enum.join
    |> spec.transform_fun.()
  end

  def xpath(parent, %SwXpath{is_list: false, is_value: true, cast_to: cast, is_optional: is_opt?} = spec) do
    get_current_entities(parent, spec) |> _value |> to_cast(cast, is_opt?) |> spec.transform_fun.()
  end

  def xpath(parent, %SwXpath{is_list: false, is_value: false} = spec) do
    get_current_entities(parent, spec) |> spec.transform_fun.()
  end

  def xpath(parent, sw_xpath, subspec) do
    if sw_xpath.is_list do
      current_entities = xpath(parent, sw_xpath)
      Enum.map(current_entities, fn (entity) -> xmap(entity, subspec, sw_xpath) end)
    else
      current_entity = xpath(parent, sw_xpath)
      xmap(current_entity, subspec, sw_xpath)
    end
  end

  def xmap(parent, mapping), do: xmap(parent, mapping, %{is_keyword: false})

  def xmap(nil, _, %{is_optional: true}), do: nil

  def xmap(parent, [], atom) when is_atom(atom), do: xmap(parent, [], %{is_keyword: atom})

  def xmap(_, [], %{is_keyword: false}), do: %{}

  def xmap(_, [], %{is_keyword: true}), do: []

  def xmap(parent, [{label, spec} | tail], is_keyword) when is_list(spec) do
    [sw_xpath | subspec] = spec
    result = xmap(parent, tail, is_keyword)
    put_in result[label], xpath(parent, sw_xpath, subspec)
  end

  def xmap(parent, [{label, sw_xpath} | tail], is_keyword) do
    result = xmap(parent, tail, is_keyword)
    put_in result[label], xpath(parent, sw_xpath)
  end

  defp _value(entity) do
    cond do
      is_record? entity, :xmlText ->
        xmlText(entity, :value)
      is_record? entity, :xmlComment ->
        xmlComment(entity, :value)
      is_record? entity, :xmlPI ->
        xmlPI(entity, :value)
      is_record? entity, :xmlAttribute ->
        xmlAttribute(entity, :value)
      is_record? entity, :xmlObj ->
        xmlObj(entity, :value)
      true ->
        entity
    end
  end

  defp is_record?(data, kind) do
    is_tuple(data) and tuple_size(data) > 0 and :erlang.element(1, data) == kind
  end

  defp get_current_entities(parent, %SwXpath{path: path, is_list: true, namespaces: namespaces}) do
    :xmerl_xpath.string(path, parent, [namespace: namespaces]) |> List.wrap
  end

  defp get_current_entities(parent, %SwXpath{path: path, is_list: false, namespaces: namespaces}) do
    ret = :xmerl_xpath.string(path, parent, [namespace: namespaces])
    if is_record?(ret, :xmlObj) do
      ret
    else
      List.first(ret)
    end
  end

  defp to_cast(value, false, _is_opt?), do: value
  defp to_cast(nil, _, true), do: nil
  defp to_cast(value, :string, _is_opt?), do: to_string(value)
  defp to_cast(value, :integer, _is_opt?), do: String.to_integer(to_string(value))
  defp to_cast(value, :float, _is_opt?) do
   {float,_} = Float.parse(to_string(value))
   float
  end
  defp to_cast(value, :soft_string, is_opt?) do
    if String.Chars.impl_for(value) do
      to_string(value)
    else
      if is_opt?, do: nil, else: ""
    end
  end
  defp to_cast(value, :soft_integer, is_opt?) do
    if String.Chars.impl_for(value) do
      case Integer.parse(to_string(value)) do
        :error-> if is_opt?, do: nil, else: 0
        {int,_}-> int
      end
    else
      if is_opt?, do: nil, else: 0
    end
  end
  defp to_cast(value, :soft_float, is_opt?) do
    if String.Chars.impl_for(value) do
      case Float.parse(to_string(value)) do
        :error-> if is_opt?, do: nil, else: 0.0
        {float,_}->float
      end
    else
      if is_opt?, do: nil, else: 0.0
    end
  end
end
