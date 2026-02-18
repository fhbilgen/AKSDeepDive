package authz

import rego.v1

default allow = false

# Example: allow admins
allow if {
  input.user.role == "admin"
}

# Example: allow "read" to anyone in IT
allow if {
  input.action == "read"
  input.user.department == "IT"
}

# Optional: return denial reasons (useful for logs/UX)
deny contains msg if {
  not allow
  msg := sprintf("Denied: role=%v dept=%v action=%v resource=%v",
    [input.user.role, input.user.department, input.action, input.resource])
}
