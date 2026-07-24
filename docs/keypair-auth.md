# Key-Pair Auth for Service Accounts

Snowflake recommends RSA key-pair auth over passwords for service accounts
(`DBT_CICD`, `PROD_DBT`): no shared secret to rotate through GitHub, and keys
can be rotated one at a time via `RSA_PUBLIC_KEY` / `RSA_PUBLIC_KEY_2`.

The Terraform and dbt scaffolding for this is already in place but **inactive**:

- `terraform/snowflake/users.tf` -- both service users accept an optional
  `rsa_public_key` (null by default, so nothing changes until you set it)
- `dbt/profiles.yml` -- commented `private_key_path` lines on the `prod` and
  `staging` targets

Password auth keeps working the whole time; Snowflake allows both credentials
on one user, so this is a zero-downtime cutover.

## 1. Generate a key pair (one per service account)

```bash
# Private key (PKCS#8, encrypted -- you'll be prompted for a passphrase)
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out dbt_cicd_rsa_key.p8

# Public key
openssl rsa -in dbt_cicd_rsa_key.p8 -pubout -out dbt_cicd_rsa_key.pub
```

Repeat with `prod_dbt_` filenames for `PROD_DBT`. Keep the `.p8` files out of
git (store them in a password manager / secret store).

## 2. Attach the public key via Terraform

Snowflake wants the PEM *body only* (no `-----BEGIN/END PUBLIC KEY-----`
lines, no newlines):

```bash
grep -v "PUBLIC KEY" dbt_cicd_rsa_key.pub | tr -d '\n'
```

Set the value as a Terraform variable (tfvars or environment):

```bash
export TF_VAR_cicd_rsa_public_key='MIIBIjANBgkqh...'
export TF_VAR_prod_dbt_rsa_public_key='MIIBIjANBgkqh...'

cd terraform/snowflake
terraform plan   # expect: update in-place on the two snowflake_user resources
terraform apply
```

## 3. Wire the private key into each consumer

### GitHub Actions (DBT_CICD)

1. Add repo secrets:
   - `SNOWFLAKE_PRIVATE_KEY` -- full contents of `dbt_cicd_rsa_key.p8`
   - `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` -- the passphrase from step 1
2. In the workflows, materialize the key to a file and export the env vars the
   profile reads:

   ```yaml
   - name: Write Snowflake private key
     run: |
       echo "${{ secrets.SNOWFLAKE_PRIVATE_KEY }}" > $RUNNER_TEMP/snowflake_key.p8
       echo "SNOWFLAKE_PRIVATE_KEY_PATH=$RUNNER_TEMP/snowflake_key.p8" >> "$GITHUB_ENV"
       echo "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=${{ secrets.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE }}" >> "$GITHUB_ENV"
   ```

### Airflow (PROD_DBT)

Mount `prod_dbt_rsa_key.p8` into the container and set
`SNOWFLAKE_PRIVATE_KEY_PATH` / `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE` in
`dbt-dags/.env` (cosmos passes profile env through to dbt).

## 4. Flip the profile

In `dbt/profiles.yml`, on the `prod` and `staging` targets: delete the
`password:` line and uncomment the two `private_key_*` lines. Verify with:

```bash
dbt debug --profiles-dir ./ --target prod
```

## 5. Retire the passwords (later, deliberate step)

Once both consumers authenticate with keys for a full cycle (one deploy, one
scheduled run, one PR check), remove `password = var.*_password` from the two
users in `users.tf`, apply, and delete the `SNOWFLAKE_PASSWORD` GitHub secret.

## Rotation

Set the new key as `RSA_PUBLIC_KEY_2` (add a second variable/attribute),
switch consumers to the new private key, then clear the old `RSA_PUBLIC_KEY`.
Never an outage, never a shared-secret handoff.
