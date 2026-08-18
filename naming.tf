# Derives database names and IAM usernames for the `apps` variable, then
# merges the result with `iam_db_users` before it reaches users.tf's
# for_each. `iam_db_users` itself is never modified — its entries pass
# through unchanged. `db_users` is never modified either — it's only read
# here to fold its usernames into the collision check.
#
# Sanitization is lowercasing and replacing `-` with `_`. This is the only
# place that happens; callers must pass raw, unsanitized names.
locals {
  apps_database_name = {
    for app, _ in var.apps : app => lower(replace(app, "-", "_"))
  }

  # Every derived database name (primary + extra_databases), each paired
  # with a human-readable source, flattened across all apps. Flattening
  # (instead of grouping by app) is what lets us catch two extra_databases
  # entries in the *same* app that sanitize to the same name (e.g. "Reports"
  # and "reports"), not just collisions between different apps.
  apps_primary_and_extra_pairs = flatten([
    for app, cfg in var.apps : concat(
      [{
        db     = local.apps_database_name[app]
        app    = app
        source = "app \"${app}\" primary database"
      }],
      [
        for extra in cfg.extra_databases : {
          db     = "${local.apps_database_name[app]}_${lower(replace(extra, "-", "_"))}"
          app    = app
          source = "app \"${app}\" extra_databases entry \"${extra}\""
        }
      ]
    )
  ])

  apps_database_name_sources = {
    for name in distinct([for p in local.apps_primary_and_extra_pairs : p.db]) :
    name => [for p in local.apps_primary_and_extra_pairs : p.source if p.db == name]
  }

  # Any derived database name claimed by more than one source — whether
  # that's two different apps, or two extra_databases entries in one app.
  apps_database_collisions = {
    for name, sources in local.apps_database_name_sources : name => sources
    if length(sources) > 1
  }

  # Tolerant (last-wins) — safe because the precondition below blocks the
  # apply before a real collision could ever reach real infrastructure.
  apps_database_owners = merge([
    for p in local.apps_primary_and_extra_pairs : { (p.db) = p.app }
  ]...)

  # Every database a given app owns, keyed by app — reused by
  # apps_service_entries below so the list of an app's databases only gets
  # derived once, not recomputed per service.
  apps_databases_by_app = {
    for app, _ in var.apps :
    app => [for p in local.apps_primary_and_extra_pairs : p.db if p.app == app]
  }

  apps_service_entries = flatten([
    for app, cfg in var.apps : [
      for service, svc in cfg.services : {
        username   = "${local.apps_database_name[app]}_${lower(replace(service, "-", "_"))}"
        databases  = local.apps_databases_by_app[app]
        privileges = svc.privileges
        source     = "app \"${app}\" service \"${service}\""
      }
    ]
  ])

  legacy_iam_db_user_entries = [
    for username, cfg in var.iam_db_users : {
      username   = username
      databases  = cfg.databases
      privileges = cfg.privileges
      source     = "iam_db_users entry \"${username}\""
    }
  ]

  # Legacy iam_db_users entries plus apps-derived entries — this is what
  # users.tf's iam_db_user resources actually loop over. db_users is
  # deliberately left out: it has its own separate (password-based)
  # resources in users.tf that this must not touch. It's still included in
  # the username collision check below, just not in this map.
  combined_iam_db_user_entries = concat(local.legacy_iam_db_user_entries, local.apps_service_entries)

  combined_iam_db_users = merge([
    for e in local.combined_iam_db_user_entries : {
      (e.username) = {
        databases  = e.databases
        privileges = e.privileges
      }
    }
  ]...)

  # db_users is a separate resource path, but it creates roles in the same
  # Postgres username namespace as iam_db_users/apps, so a collision with it
  # is just as real and worth catching here.
  db_users_username_sources = [
    for username, _ in var.db_users : {
      username = username
      source   = "db_users entry \"${username}\""
    }
  ]

  all_username_sources = concat(
    [for e in local.combined_iam_db_user_entries : { username = e.username, source = e.source }],
    local.db_users_username_sources
  )

  username_sources = {
    for name in distinct([for e in local.all_username_sources : e.username]) :
    name => [for e in local.all_username_sources : e.source if e.username == name]
  }

  username_collisions = {
    for name, sources in local.username_sources : name => sources
    if length(sources) > 1
  }

  apps_database_collision_message = join("; ", [
    for name, sources in local.apps_database_collisions :
    "\"${name}\" claimed by ${join(" and ", sources)}"
  ])

  username_collision_message = join("; ", [
    for name, sources in local.username_collisions :
    "\"${name}\" claimed by ${join(" and ", sources)}"
  ])
}

resource "terraform_data" "apps_database_collision_check" {
  # Only exists when `apps` is actually used, so a caller who never touches
  # `apps` (every existing iam_db_users/db_users consumer today) sees no new
  # resource in their plan at all — not even a harmless no-op create.
  count = length(var.apps) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.apps_database_collisions) == 0
      error_message = "Colliding database name(s) derived from apps: ${local.apps_database_collision_message}. Rename the conflicting app or extra_databases entry so derived names are unique."
    }
  }
}

resource "terraform_data" "apps_username_collision_check" {
  # Same reasoning: only exists once there's an `apps` entry that could
  # possibly collide with another `apps` entry, an `iam_db_users` key, or a
  # `db_users` key.
  count = length(var.apps) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.username_collisions) == 0
      error_message = "Colliding IAM database username(s): ${local.username_collision_message}."
    }
  }
}
