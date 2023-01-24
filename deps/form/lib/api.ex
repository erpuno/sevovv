defmodule FORM.Combo.Sample do
  # TODO: write document in man folder for form.n2o.dev
  require FORM
  require NITRO
  def doc(), do: {:api,1,2}
  def id(), do: 1
  def new(name, obj, options), do: FORM.document()
  def proto(msg), do: NITRO.proto(msg)
  def index(), do: [:name, :id]
  def item({:api,x,y}), do: :nitro.jse("#{x} #{y}")
  def view_value({:api,x,y}), do: :io_lib.format('~p ~p',[x,y])
end
