defmodule Sax do
  @moduledoc ~S"""
  Sax is an XML SAX parser and encoder.

  Sax provides functions to parse XML file in both binary and streaming way in compliant
  with [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/xml/).

  Sax also offers DSL and API to build, compose and encode XML document.
  See "Encoder" section below for more information.

  ## Parser

  Sax parser supports two modes of parsing: SAX and simple form.

  ### SAX mode (Simple API for XML)

  SAX is an event driven algorithm for parsing XML documents. A SAX parser takes XML document as the input
  and emits events out to a pre-configured event handler during parsing.

  There are 5 types of SAX events supported by Sax:

  * `:start_document` - after prolog is parsed.
  * `:start_element` - when open tag is parsed.
  * `:characters` - when a chunk of `CharData` is parsed.
  * `:end_element` - when end tag is parsed.
  * `:end_document` - when the root element is closed.

  See `Sax.Handler` for more information.

  ### Simple form mode

  Sax supports parsing XML documents into a simple format. See `Sax.SimpleForm` for more details.

  ### Encoding

  Sax **only** supports UTF-8 encoding. It also respects the encoding set in XML document prolog, which means
  that if the declared encoding is not UTF-8, the parser stops. Anyway, when there is no encoding declared,
  Sax defaults the encoding to UTF-8.

  ### Reference expansion

  Sax supports expanding character references and XML 1.0 predefined entity references, for example `&#65;`
  is expanded to `"A"`, `&#x26;` to `"&"`, and `&amp;` to `"&"`.

  Sax does not expand external entity references, but provides an option to specify how they should be handled.
  See more in "Shared options" section.

  ### Creation of atoms

  Sax does not create atoms during the parsing process.

  ### DTD and XSD

  Sax does not support parsing DTD (Doctype Definition) and XSD schemas. When encountering DTD, the parser simply
  skips that.

  ### Configuration

  Sax allows streaming feature to be configured off in compile time. This could give some performance gain when
  you use Sax to parse documents those are fully loaded in the memory.

  Note that this will make streaming feature not working. It's turned on by default.

  ```
  # config/config.exs
  config :sax, :parser, streaming: false
  ```

  ### Shared options

  * `:expand_entity` - specifies how external entity references should be handled. Three supported strategies respectively are:
    * `:keep` - keep the original binary, for example `Orange &reg;` will be expanded to `"Orange &reg;"`, this is the default strategy.
    * `:skip` - skip the original binary, for example `Orange &reg;` will be expanded to `"Orange "`.
    * `{mod, fun, args}` - take the applied result of the specified MFA.

  ## Encoder

  Sax offers two APIs to build simple form and encode XML document.

  Use `Sax.XML` to build and compose XML simple form, then `Sax.encode!/2`
  to encode the built element into XML binary.

      iex> import Sax.XML
      iex> element = element("person", [gender: "female"], "Alice")
      {"person", [{"gender", "female"}], [{:characters, "Alice"}]}
      iex> Sax.encode!(element, [])
      "<?xml version=\"1.0\"?><person gender=\"female\">Alice</person>"

  See `Sax.XML` for more XML building APIs.

  Sax also provides `Sax.Builder` protocol to help composing structs into simple form.

      defmodule Person do
        @derive {Sax.Builder, name: "person", attributes: [:gender], children: [:name]}

        defstruct [:gender, :name]
      end

      iex> jack = %Person{gender: :male, name: "Jack"}
      iex> john = %Person{gender: :male, name: "John"}
      iex> import Sax.XML
      iex> root = element("people", [], [jack, john])
      iex> Sax.encode!(root, [])
      "<?xml version=\"1.0\"?><people><person gender=\"male\">Jack</person><person gender=\"male\">John</person></people>"

  """

  alias Sax.{
    Encoder,
    Parser,
    State
  }

  @doc ~S"""
  Parses XML binary data.

  This function takes XML binary, SAX event handler (see more at `Sax.Handler`) and an initial state as the input, it returns
  `{:ok, state}` if parsing is successful, otherwise `{:error, exception}`, where `exception` is a
  `Sax.ParseError` struct which can be converted into readable message with `Exception.message/1`.

  The third argument `state` can be used to keep track of data and parsing progress when parsing is happening, which will be
  returned when parsing finishes.

  ### Options

  See the “Shared options” section at the module documentation.

  ## Examples

      defmodule MyTestHandler do
        @behaviour Sax.Handler

        def handle_event(:start_document, prolog, state) do
          {:ok, [{:start_document, prolog} | state]}
        end

        def handle_event(:end_document, _data, state) do
          {:ok, [{:end_document} | state]}
        end

        def handle_event(:start_element, {name, attributes}, state) do
          {:ok, [{:start_element, name, attributes} | state]}
        end

        def handle_event(:end_element, name, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
        end
      end

      iex> xml = "<?xml version='1.0' ?><foo bar='value'></foo>"
      iex> Sax.parse_string(xml, MyTestHandler, [])
      {:ok,
       [{:end_document},
        {:end_element, "foo"},
        {:start_element, "foo", [{"bar", "value"}]},
        {:start_document, [version: "1.0"]}]}
  """

  @spec parse_string(
          data :: binary,
          handler :: module(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, state :: term()} | {:error, exception :: Sax.ParseError.t()}
  def parse_string(data, handler, initial_state, options \\ [])
      when is_binary(data) and is_atom(handler) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity
    }

    case Parser.Prolog.parse(data, false, data, 0, state) do
      {:ok, state} ->
        {:ok, state.user_state}

      {:error, _reason} = error ->
        error
    end
  end

  @doc ~S"""
  Parses XML stream data.

  This function takes a stream, SAX event handler (see more at `Sax.Handler`) and an initial state as the input, it returns
  `{:ok, state}` if parsing is successful, otherwise `{:error, exception}`, where `exception` is a
  `Sax.ParseError` struct which can be converted into readable message with `Exception.message/1`.

  ## Examples

      defmodule MyTestHandler do
        @behaviour Sax.Handler

        def handle_event(:start_document, prolog, state) do
          {:ok, [{:start_document, prolog} | state]}
        end

        def handle_event(:end_document, _data, state) do
          {:ok, [{:end_document} | state]}
        end

        def handle_event(:start_element, {name, attributes}, state) do
          {:ok, [{:start_element, name, attributes} | state]}
        end

        def handle_event(:end_element, name, state) do
          {:ok, [{:end_element, name} | state]}
        end

        def handle_event(:characters, chars, state) do
          {:ok, [{:chacters, chars} | state]}
        end
      end

      iex> stream = File.stream!("./test/support/fixture/foo.xml")
      iex> Sax.parse_stream(stream, MyTestHandler, [])
      {:ok,
       [{:end_document},
        {:end_element, "foo"},
        {:start_element, "foo", [{"bar", "value"}]},
        {:start_document, [version: "1.0"]}]}

  ## Memory usage

  `Sax.parse_stream/3` takes a `File.Stream` or `Stream` as the input, so the amount of bytes to buffer in each
  chunk can be controlled by `File.stream!/3` API.

  During parsing, the actual memory used by Sax might be higher than the number configured for each chunk, since
  Sax holds in memory some parsed parts of the original binary to leverage Erlang sub-binary extracting. Anyway,
  Sax tries to free those up when it makes sense.

  ### Options

  See the “Shared options” section at the module documentation.

  """

  @spec parse_stream(
          stream :: Enumerable.t(),
          handler :: module(),
          initial_state :: term(),
          options :: Keyword.t()
        ) :: {:ok, state :: term()} | {:error, exception :: Sax.ParseError.t()}

  def parse_stream(stream, handler, initial_state, options \\ []) do
    expand_entity = Keyword.get(options, :expand_entity, :keep)

    state = %State{
      prolog: nil,
      handler: handler,
      user_state: initial_state,
      expand_entity: expand_entity
    }

    init = Parser.Prolog.parse(<<>>, true, <<>>, 0, state)

    stream
    |> Enum.reduce_while(init, &stream_reducer/2)
    |> case do
      {:halted, context_fun} ->
        case context_fun.(<<>>, false) do
          {:ok, state} -> {:ok, state.user_state}
          {:error, reason} -> {:error, reason}
        end

      {:ok, state} ->
        {:ok, state.user_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stream_reducer(next_bytes, {:halted, context_fun}) do
    {:cont, context_fun.(next_bytes, true)}
  end

  defp stream_reducer(_next_bytes, {:error, _reason} = error) do
    {:halt, error}
  end

  defp stream_reducer(_next_bytes, {:ok, state}) do
    {:halt, {:ok, state}}
  end

  @doc """
  Encodes a simple form XML element into string.

  This function encodes an element in simple form format and a prolog to an XML document.

  ## Examples

      iex> import Sax.XML
      iex> root = element(:foo, [{"foo", "bar"}], "bar")
      iex> prolog = [version: "1.0"]
      iex> Sax.encode!(root, prolog)
      "<?xml version=\\"1.0\\"?><foo foo=\\"bar\\">bar</foo>"

  """

  @spec encode!(root :: Sax.XML.element(), prolog :: Sax.Prolog.t() | Keyword.t()) :: String.t()

  def encode!(root, prolog \\ []) do
    root
    |> Encoder.encode_to_iodata(prolog)
    |> IO.iodata_to_binary()
  end

  @doc """
  Encodes a simple form element into IO data.

  Same as `encode!/2` but this encodes the document into IO data.

  ## Examples

      iex> import Sax.XML
      iex> root = element(:foo, [{"foo", "bar"}], "bar")
      iex> prolog = [version: "1.0"]
      iex> Sax.encode_to_iodata!(root, prolog)
      [
        ['<?xml', [32, 'version', 61, 34, "1.0", 34], [], [], '?>'],
        [60, "foo", 32, "foo", 61, 34, "bar", 34],
        62,
        ["bar"],
        [60, 47, "foo", 62]
      ]

  """
  @spec encode_to_iodata!(root :: Sax.XML.element(), prolog :: Sax.Prolog.t() | Keyword.t()) :: iodata()

  def encode_to_iodata!(root, prolog \\ []) do
    Encoder.encode_to_iodata(root, prolog)
  end
end
