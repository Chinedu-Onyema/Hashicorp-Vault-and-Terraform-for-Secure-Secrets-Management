provider "aws" {
  region = "eu-west-2"
}

# Authenticate terraform with hashicorp vault
provider "vault" {
  address           = "http://16.61.137.45:8200"   # your own EC2 public IPV4 address and vault port
  skip_child_token  = true

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = "27370f45-dc55-1d44-0e39-33d9f3600966"      # your own role id
      secret_id = "5c9bd9aa-d229-9790-0453-3158c1a6ae31"      # your own secret id
    }
  }
}

# create a random id resource suffix for a unique S3 bucket name

resource "random_id" "suffix" {
  byte_length = 4
}


# S3 bucket name is not sensitive and is safe to persist in the terraform.tfstate file

resource "aws_s3_bucket" "infra" {
  bucket = "chinedu-secrets-bucket-${random_id.suffix.hex}"

  tags = {
    Name = "s3_vault_infra"
  }
}

# Block public access to this bucket because it holds sensitive content

resource "aws_s3_bucket_public_access_block" "infra" {
  bucket = aws_s3_bucket.infra.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Fetch the secret from Vault so it is never persisted to the terraform.tfstate file
# ephemeral guarantees this value is never written to state
# in scenarios where you do not want to hardcode values like a resource name
# in yiur code, then use the data attribute

ephemeral "vault_kv_secret_v2" "s3_secret" {
  mount = "kvsecret"              # name of your path in hashicorp vault
  name  = "sensitive-secrets"     # name of your secret in hashicorp vault
}

# Upload the secret to S3 directly using the local exec provisioner.
# this is the supported way to write an ephemeral value to S3 without it touching the terraform.tfstate file

resource "terraform_data" "upload_secret" {
  depends_on = [aws_s3_bucket_public_access_block.infra]    # before terraform uploads the secret
                                                            # the bucket must already be created

# Use the local-exec provisioner to write a bash script to copy the secrets from terraform vault 
# to your created S3 bucket inside the secrets prefix. 
# ephemeral won't save the details of this file in your terraform.tfstate file
# or folder and it should be written as an object into a text file called secret-id.txt
# secret_id should be the name of your key in hashicorp vault

  provisioner "local-exec" {
    command = "echo '${ephemeral.vault_kv_secret_v2.s3_secret.data["secret_id"]}' | aws s3 cp - s3://${aws_s3_bucket.infra.id}/secrets/secret-id.txt"
  }
}