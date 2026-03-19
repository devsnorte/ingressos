defmodule PretexWeb.PageController do
  use PretexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
