defmodule Pretex.CheckIns.GateCheckInList do
  use Ecto.Schema

  @primary_key false
  schema "gate_check_in_lists" do
    belongs_to(:gate, Pretex.CheckIns.Gate)
    belongs_to(:check_in_list, Pretex.CheckIns.CheckInList)
  end
end
