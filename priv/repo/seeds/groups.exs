alias Dbservice.Repo
alias Dbservice.Groups.Group
alias Dbservice.Products.Product
alias Dbservice.Groups.AuthGroup
alias Dbservice.Schools.School
alias Dbservice.Batches.Batch
alias Dbservice.Statuses.Status

IO.puts("  → Seeding groups...")

# Get all the entities that need group records
products = Repo.all(Product)
auth_groups = Repo.all(AuthGroup)
schools = Repo.all(School)
batches = Repo.all(Batch)
statuses = Repo.all(Status)

groups_created = 0

# Create groups for products
for product <- products do
  unless Repo.get_by(Group, type: "product", child_id: product.id) do
    %Group{}
    |> Group.changeset(%{
      type: "product",
      child_id: product.id
    })
    |> Repo.insert!()
    groups_created = groups_created + 1
  end
end

# Create groups for auth_groups
for auth_group <- auth_groups do
  unless Repo.get_by(Group, type: "auth_group", child_id: auth_group.id) do
    %Group{}
    |> Group.changeset(%{
      type: "auth_group",
      child_id: auth_group.id
    })
    |> Repo.insert!()
    groups_created = groups_created + 1
  end
end

# Create groups for schools
for school <- schools do
  unless Repo.get_by(Group, type: "school", child_id: school.id) do
    %Group{}
    |> Group.changeset(%{
      type: "school",
      child_id: school.id
    })
    |> Repo.insert!()
    groups_created = groups_created + 1
  end
end

# Create groups for batches
for batch <- batches do
  unless Repo.get_by(Group, type: "batch", child_id: batch.id) do
    %Group{}
    |> Group.changeset(%{
      type: "batch",
      child_id: batch.id
    })
    |> Repo.insert!()
    groups_created = groups_created + 1
  end
end

# Create groups for statuses
for status <- statuses do
  unless Repo.get_by(Group, type: "status", child_id: status.id) do
    %Group{}
    |> Group.changeset(%{
      type: "status",
      child_id: status.id
    })
    |> Repo.insert!()
    groups_created = groups_created + 1
  end
end

total_entities = length(products) + length(auth_groups) + length(schools) + length(batches) + length(statuses)
IO.puts("    ✅ Groups seeded (#{total_entities} total entities, #{groups_created} new groups created)")
