# Derives database names and IAM usernames for the `apps` variable and
# merges the result with `iam_db_users` before users.tf's for_each.
# `iam_db_users`/`db_users` are never modified — the latter is only read
# here to fold its usernames into the collision check.
#
# Sanitization (lowercase, `-` -> `_`) happens only here; callers pass raw
# names.
locals {
  apps_database_name = {
    for app, _ in var.apps : app => lower(replace(app, "-", "_"))
  }

  # Keyed by the raw extra_databases name, so collision detection and
  # per-service scoping below both look names up here instead of
  # re-deriving them.
  apps_extra_database_names = {
    for app, cfg in var.apps : app => {
      for extra in cfg.extra_databases :
      extra => "${local.apps_database_name[app]}_${lower(replace(extra, "-", "_"))}"
    }
  }

  # Flattened (not grouped by app) so two extra_databases entries in the
  # *same* app that sanitize to the same name (e.g. "Reports"/"reports")
  # are caught too, not just collisions across different apps.
  apps_primary_and_extra_pairs = flatten([
    for app, cfg in var.apps : concat(
      [{
        db     = local.apps_database_name[app]
        app    = app
        source = "app \"${app}\" primary database"
      }],
      [
        for extra, db in local.apps_extra_database_names[app] : {
          db     = db
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

  # Also blocked by the variable validation above, but that's not
  # guaranteed to run before the lookup below, which would otherwise crash
  # on a bad reference — so it's filtered defensively there and reported
  # as a precondition here instead.
  apps_undeclared_service_extra_databases = flatten([
    for app, cfg in var.apps : [
      for service, svc in cfg.services : [
        for extra in svc.extra_databases :
        "app \"${app}\" service \"${service}\" extra_databases entry \"${extra}\""
        if !contains(cfg.extra_databases, extra)
      ]
    ]
  ])

  # Single source of truth for a service's username — apps_database_owner_username
  # below looks usernames up here instead of re-deriving the string, so the
  # two can't silently diverge if this rule ever changes.
  apps_service_username = {
    for app, cfg in var.apps : app => {
      for service, _ in cfg.services : service => "${local.apps_database_name[app]}_${lower(replace(service, "-", "_"))}"
    }
  }

  # Each service gets the primary database plus only its own declared
  # extra_databases — never a sibling service's databases by default.
  apps_service_entries = flatten([
    for app, cfg in var.apps : [
      for service, svc in cfg.services : {
        username = local.apps_service_username[app][service]
        databases = concat(
          [local.apps_database_name[app]],
          [
            for extra in svc.extra_databases :
            local.apps_extra_database_names[app][extra]
            if contains(cfg.extra_databases, extra)
          ]
        )
        privileges = svc.privileges
        source     = "app \"${app}\" service \"${service}\""
      }
    ]
  ])

  # Distinguishes apps-sourced roles from legacy iam_db_users/db_users roles
  # after the merge below.
  apps_service_usernames = toset([for e in local.apps_service_entries : e.username])

  # A database gets an OWNER only when exactly one service uses it. Shared
  # databases are owned by the master user instead (deferred product
  # decision on which service, if any, should own them — see README) and
  # get a schema-level CREATE grant instead (iam-user-create.sh.tftpl).
  apps_database_owner_username = merge([
    for app, cfg in var.apps : merge(
      length(cfg.services) == 1 ? {
        (local.apps_database_name[app]) = local.apps_service_username[app][keys(cfg.services)[0]]
      } : {},
      {
        for extra, db in local.apps_extra_database_names[app] :
        db => local.apps_service_username[app][
          [for service, svc in cfg.services : service if contains(svc.extra_databases, extra)][0]
        ]
        if length([for service, svc in cfg.services : service if contains(svc.extra_databases, extra)]) == 1
      }
    )
  ]...)

  # Subset of each apps-sourced role's databases it owns. lookup(), not
  # direct indexing — a shared/unused database has no entry above.
  apps_service_owned_databases = {
    for e in local.apps_service_entries : e.username => [
      for db in e.databases : db
      if lookup(local.apps_database_owner_username, db, "") == e.username
    ]
  }

  legacy_iam_db_user_entries = [
    for username, cfg in var.iam_db_users : {
      username   = username
      databases  = cfg.databases
      privileges = cfg.privileges
      source     = "iam_db_users entry \"${username}\""
    }
  ]

  # What users.tf's iam_db_user resources loop over. db_users stays out of
  # this (it has its own separate password-based resources) but is still
  # checked for username collisions below.
  combined_iam_db_user_entries = concat(local.legacy_iam_db_user_entries, local.apps_service_entries)

  combined_iam_db_users = merge([
    for e in local.combined_iam_db_user_entries : {
      (e.username) = {
        databases  = e.databases
        privileges = e.privileges
      }
    }
  ]...)

  # db_users creates roles in the same Postgres username namespace, so a
  # collision with it is just as real despite the separate resource path.
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

  apps_undeclared_service_extra_databases_message = join("; ", local.apps_undeclared_service_extra_databases)
}

# All three checks below only exist once `apps` is used, so a caller who
# never touches it (every existing iam_db_users/db_users consumer today)
# sees no new resources in their plan at all.

resource "terraform_data" "apps_database_collision_check" {
  count = length(var.apps) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.apps_database_collisions) == 0
      error_message = "Colliding database name(s) derived from apps: ${local.apps_database_collision_message}. Rename the conflicting app or extra_databases entry so derived names are unique."
    }
  }
}

resource "terraform_data" "apps_username_collision_check" {
  count = length(var.apps) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.username_collisions) == 0
      error_message = "Colliding IAM database username(s): ${local.username_collision_message}."
    }
  }
}

resource "terraform_data" "apps_service_extra_databases_check" {
  count = length(var.apps) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.apps_undeclared_service_extra_databases) == 0
      error_message = "Service extra_databases not declared by their app: ${local.apps_undeclared_service_extra_databases_message}. Add the entry to the app's own extra_databases first."
    }
  }
}

# apps only creates databases and manages ownership on the postgresql
# branch of iam-user-create.sh.tftpl/iam-user-destroy.sh.tftpl — on MySQL
# it would create roles and grant on databases that were never created,
# failing at runtime instead of here.
resource "terraform_data" "apps_engine_check" {
  count = length(var.apps) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.engine == "postgresql"
      error_message = "apps is only supported with engine = \"postgresql\"."
    }
  }
}
