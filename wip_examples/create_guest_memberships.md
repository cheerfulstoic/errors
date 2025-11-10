```elixir
  defp create_guest_memberships(team_membership, guest_invitations, now) do
    Enum.reduce_while(guest_invitations, {:ok, []}, fn guest_invitation,
                                                       {:ok, guest_memberships} ->
      result =
        team_membership
        |> Teams.GuestMembership.changeset(guest_invitation.site, guest_invitation.role)
        |> Repo.insert(
          on_conflict: [set: [updated_at: now]],
          conflict_target: [:team_membership_id, :site_id]
        )

      case result do
        {:ok, guest_membership} -> {:cont, {:ok, [guest_membership | guest_memberships]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end
```

```elixir
  defp create_guest_memberships(team_membership, guest_invitations, now) do
    Triage.map_if(guest_invitations, fn guest_invitation ->
      team_membership
      |> Teams.GuestMembership.changeset(guest_invitation.site, guest_invitation.role)
      |> Repo.insert(
        on_conflict: [set: [updated_at: now]],
        conflict_target: [:team_membership_id, :site_id]
      )
    end)
    # if reverse is important...
    |> Triage.then(&Enum.reverse/1)
  end
```

# Would it make sense for this to go into a transaction?  So that it rolls back if there's an error?

