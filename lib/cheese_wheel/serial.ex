# Note, this is an undocumented fork of https://github.com/edgurgel/bertex
# which has not been updated in 4 years :(
# Unfortunately they did not leave the elixir version open
# So using it in the mix file would not work.
# This is a work TOTALLY based on @mojombo and @eproxus work:
# More at: https://github.com/eproxus/bert.erl and http://github.com/mojombo/bert.erl
# Minor changes have been made to be compatible with current day Elixir
# Preserved LICENSE:
# Copyright (c) 2013 Eduardo Gurgel Pinho
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
defmodule CheeseWheel.Serial do
  @moduledoc false
  import :erlang, only: [binary_to_term: 1,
                         binary_to_term: 2,
                         term_to_binary: 1]

  defprotocol Bert do
    @fallback_to_any true
    def encode(term)
    def decode(term)
  end

  defimpl Bert, for: Atom do
    def encode(false), do: {:bert, false}
    def encode(true), do: {:bert, true}
    def encode(atom), do: atom

    def decode(atom), do: atom
  end

  defimpl Bert, for: List do
    def encode([]), do: {:bert, nil}
    def encode(list) do
      Enum.map(list, &Bert.encode(&1))
    end

    def decode(list) do
      Enum.map(list, &Bert.decode(&1))
    end
  end

  # Inspired by talentdeficit/jsex solution
  defimpl Bert, for: Tuple do
    def encode(tuple) do
      Tuple.to_list(tuple)
        |> Enum.map(&Bert.encode(&1))
        |> List.to_tuple
    end

    def decode({:bert, nil}), do: []

    def decode({:bert, true}), do: true

    def decode({:bert, false}), do: false


    def decode({:bert, :dict, dict}), do: Enum.into(Bert.decode(dict), %{})

    # Structs is something I made.
    def decode({:struct, mod, struct}), do: Kernel.struct(mod, Bert.decode(struct))

    def decode(tuple) do
      Tuple.to_list(tuple)
        |> Enum.map(&Bert.decode(&1))
        |> List.to_tuple
    end
  end

  defimpl Bert, for: Map do
    def encode(dict), do: {:bert, :dict, Map.to_list(dict)}
    # This should never happen.
    def decode(dict), do: Enum.into(dict, %{})
  end

  defimpl Bert, for: HashDict do
    def encode(dict), do: {:bert, :dict, Map.to_list(dict)}
    # This should never happen.
    def decode(dict), do: Enum.into(dict, %{})
  end

  defimpl Bert, for: Any do
    # Unfortunately, I can't do a `for: Struct`. :(
    def encode(%{__struct__: mod} = struct), do: {:struct, mod, Bert.encode(Map.from_struct(struct))}
    def encode(term), do: term
    def decode(term), do: term
  end

  @spec encode(term) :: binary
  def encode(term) do
    Bert.encode(term) |> term_to_binary
  end

  @spec decode(binary) :: term
  def decode(bin) do
    binary_to_term(bin) |> Bert.decode
  end

  @spec safe_decode(binary) :: term
  def safe_decode(bin) do
    binary_to_term(bin, [:safe]) |> Bert.decode
  end

end
