Vault Dead Lease Remover
---
This script is a interim solution for [vault lease expiration issue]. Will force revoke lease is expired more than 1 day (default).

It have some parameter can turn by environment variable:
- `KILL_SECOND`: Define how long time that lease expired will force revoke. (Default: 86400, which is 1 day) 
- `VAULT_ENDPOINT`: Define where to connect vault. Need protocol and port. (Default: "https://127.0.0.1:8200")
- `DB_CRED_LEASE_PREFIX`: Define lease prefix. (Default: "database/creds", because I use it for DB secret engine lease) 
- `X_VAULT_TOKEN`: Define vault token for calling vault API. (Default: `NOT DEFINED`.)
- `VAULT_ROLE`: Define role name for  use K8S service account JWT login to vault. If not defined. Then it won't login to vault. Directly use vault token from `X_VAULT_TOKEN` (Default: `NOT DEFINED`.)

## Policy in vault:
Below policiy to make it have enough permission to perform lookup and force-revoke.
Assumption:
- Only remove lease from DB secret engine. If you change `DB_CRED_LEASE_PREFIX`. You also need to change below path.
```hcl
path "sys/leases/revoke-force/database/creds/*" {
  capabilities = ["update", "sudo"]
}
path "sys/leases/lookup/database/creds/*" {
  capabilities = ["list", "update", "sudo"]
}
```

## Example for deploy in K8S cronjob
Here is an example K8S YAML. to deploy K8S cronjob to run this script.
Assumption:
- The vault have a service called `vault` in `services` namespace.
- Vault already config policy and role for K8S service account `dead-lease-remover` in `services` namespace.
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dead-lease-remover
  namespace: services
---
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  labels:
    app: vault-dead-lease-remover
  name: vault-dead-lease-remover
spec:
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: vault-dead-lease-remover
        spec:
          containers:
          - name: dead-lease-remover
            image: alantang888/vault_dead_lease_remover:0.2
            imagePullPolicy: Always
            env:
            - name: VAULT_ROLE
              value: dead-lease-remover
            - name: VAULT_ENDPOINT
              value: https://vault.services:8200
            resources:
              limits:
                cpu: 200m
                memory: 256Mi
              requests:
                cpu: 100m
                memory: 128Mi
          restartPolicy: Never
          serviceAccountName: dead-lease-remover
  schedule: 5 22 * * *
  successfulJobsHistoryLimit: 3
  suspend: false
```

[vault lease expiration issue]: https://github.com/hashicorp/vault/issues/6058
