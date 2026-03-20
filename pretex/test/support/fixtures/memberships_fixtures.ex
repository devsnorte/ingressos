defmodule Pretex.MembershipsFixtures do
  alias Pretex.Memberships

  def membership_type_fixture(org, attrs \\ %{}) do
    {:ok, mt} =
      Memberships.create_membership_type(
        org,
        Enum.into(attrs, %{
          name: "Gold Member #{System.unique_integer([:positive])}",
          validity_days: 365
        })
      )

    mt
  end

  def membership_benefit_fixture(membership_type, attrs \\ %{}) do
    {:ok, benefit} =
      Memberships.create_benefit(
        membership_type,
        Enum.into(attrs, %{
          benefit_type: "percentage_discount",
          value: 1500
        })
      )

    benefit
  end

  def membership_fixture(membership_type, customer, org, attrs \\ %{}) do
    {:ok, membership} =
      Memberships.grant_membership(
        membership_type,
        customer,
        org,
        attrs
      )

    membership
  end
end
