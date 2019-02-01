#!/usr/bin/env bash

# Config section
KILL_SECOND=${KILL_SECOND=86400}
VAULT_ENDPOINT=${VAULT_ENDPOINT="https://127.0.0.1:8200"}
DB_CRED_LEASE_PREFIX=${DB_CRED_LEASE_PREFIX="database/creds"}
# End of config section

# If no vault role provide, use token directly
if  [ -z "$VAULT_ROLE" ]; then
  # Export your vault token to X_VAULT_TOKEN before use
  if [ -z "$X_VAULT_TOKEN" ]; then
    echo "Export your vault token to X_VAULT_TOKEN before use"
    exit 1
  fi
else
  # Use K8S service account JWT to login vault with VAULT_ROLE role
  SERVICE_ACCOUNT_JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  X_VAULT_TOKEN=$(curl -s -k --data "{\"jwt\": \"$SERVICE_ACCOUNT_JWT\", \"role\": \"$VAULT_ROLE\"}" -X POST $VAULT_ENDPOINT/v1/auth/kubernetes/login | jq -r '.auth.client_token')
fi

DB_CRED_LEASES=$(curl -s -k --header "X-Vault-Token: $X_VAULT_TOKEN" -X LIST $VAULT_ENDPOINT/v1/sys/leases/lookup/$DB_CRED_LEASE_PREFIX | jq -r '.data.keys[]')

for DB_CRED_LEASE in $DB_CRED_LEASES
do
  LEASE_PREFIX="$DB_CRED_LEASE_PREFIX/$DB_CRED_LEASE"
  # Get list for lease with prefix
  CURRENT_LEASES=$(curl -s -k --header "X-Vault-Token: $X_VAULT_TOKEN" -X LIST $VAULT_ENDPOINT/v1/sys/leases/lookup/$LEASE_PREFIX | jq -r ".data.keys[]")

  for LEASE in $CURRENT_LEASES
  do
    # Check TTL
    TTL=$(curl -s -k --header "X-Vault-Token: $X_VAULT_TOKEN" -d "{\"lease_id\": \"$LEASE_PREFIX$LEASE\"}" -X PUT $VAULT_ENDPOINT/v1/sys/leases/lookup |jq ".data.ttl")
    if (( $TTL < -$KILL_SECOND )); then
      echo "$LEASE_PREFIX/$LEASE --> $TTL Will force revoke"
      # Forec expire lease
      curl -s -k --header "X-Vault-Token: $X_VAULT_TOKEN" -X PUT $VAULT_ENDPOINT/v1/sys/leases/revoke-force/$LEASE_PREFIX/$LEASE
    fi
  done
done
