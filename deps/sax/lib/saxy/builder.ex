defprotocol Sax.Builder do
  @moduledoc """
  Protocol for building XML content.

  ## Deriving

  This helps to generate XML content simple form in trivial cases.

  There are a few required options:

  * `name` - tag name of generated XML element.
  * `attributes` - fields to be encoded as attributes.
  * `children` - fields to be encoded as element children.

  ## Examples

      defmodule Person do
        @derive {Sax.Builder, name: "person", attributes: [:gender], children: [:name]}

        defstruct [:name, :gender]
      end

      iex> person = %Person{name: "Alice", gender: "female"}
      iex> Sax.Builder.build(person)
      {"person", [{"gender", "female"}], [{:characters, "Alice"}]}

  Custom implementation could be done by implementing protocol:

      defmodule User do
        defstruct [:username, :name]
      end

      defimpl Sax.Builder do
        import Sax.XML

        def build(user) do
          element(
            "Person",
            [{"userName", user.username}],
            [element("Name", [], user.name)]
          )
        end
      end

      iex> user = %User{name: "Alice", username: "alice99"}
      iex> Sax.Builder.build(user)
      {"Person", [{"userName", "alice99"}], [{"Name", [], [characters: "Alice"]}]}
  """

  @doc """
  Builds `content` to XML content in simple form.
  """

  @spec build(content :: term()) :: Sax.XML.content()

  def build(content)
end

defimpl Sax.Builder, for: Any do
  defmacro __deriving__(module, _struct, options) do
    name = Keyword.fetch!(options, :name)
    attribute_fields = Keyword.get(options, :attributes, [])
    children_fields = Keyword.get(options, :children, [])

    quote do
      defimpl Sax.Builder, for: unquote(module) do
        def build(struct) do
          import Sax.XML

          attributes =
            struct
            |> Map.take(unquote(attribute_fields))
            |> Enum.to_list()

          children =
            struct
            |> Map.take(unquote(children_fields))
            |> Map.values()

          element(unquote(name), attributes, children)
        end
      end
    end
  end

  def build(%_{} = struct) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      Sax.Builder.Content doesn't know how to build this struct.

      You can derive the implementation by specifying in the module.

      @derive {
        Sax.Builder.Content,
        [name: "person",
         attributes: [:gender, :telephone],
         children: [:name]]
      }
      defstruct ...
      """
  end
end

defimpl Sax.Builder, for: Tuple do
  import Sax.XML, only: [characters: 1]

  def build({type, _} = form)
      when type in [:characters, :comment, :cdata, :reference],
      do: form

  def build({_name, _attributes, _content} = form), do: form

  def build(other) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: other,
      description: "cannot build content with tuple"
  end
end

defimpl Sax.Builder, for: BitString do
  import Sax.XML, only: [characters: 1]

  def build(binary) when is_binary(binary) do
    characters(binary)
  end

  def build(bitstring) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: bitstring,
      description: "cannot build content with a bitstring"
  end
end

defimpl Sax.Builder, for: Atom do
  import Sax.XML, only: [characters: 1]

  def build(nil), do: characters("")

  def build(value) do
    value
    |> Atom.to_string()
    |> characters()
  end
end

defimpl Sax.Builder, for: Integer do
  import Sax.XML, only: [characters: 1]

  def build(value) do
    value
    |> Integer.to_string()
    |> characters()
  end
end

defimpl Sax.Builder, for: Float do
  import Sax.XML, only: [characters: 1]

  def build(value) do
    value
    |> Float.to_string()
    |> characters()
  end
end

defimpl Sax.Builder, for: NaiveDateTime do
  import Sax.XML, only: [characters: 1]

  def build(value) do
    value
    |> NaiveDateTime.to_iso8601()
    |> characters()
  end
end

defimpl Sax.Builder, for: DateTime do
  import Sax.XML, only: [characters: 1]

  def build(value) do
    value
    |> DateTime.to_iso8601()
    |> characters()
  end
end

defimpl Sax.Builder, for: Date do
  import Sax.XML, only: [characters: 1]

  def build(value) do
    value
    |> Date.to_iso8601()
    |> characters()
  end
end

defimpl Sax.Builder, for: Time do
  import Sax.XML, only: [characters: 1]

  def build(value) do
    value
    |> Time.to_iso8601()
    |> characters()
  end
end
