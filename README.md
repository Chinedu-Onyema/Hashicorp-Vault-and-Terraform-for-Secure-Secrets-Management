# Implementing HashiCorp Vault for Secret Management in Terraform

This a complete, practical walkthrough on integrating HashiCorp Vault with Terraform to eliminate hardcoded credentials and prevent sensitive values from being persisted in plain text inside terraform.tfstate files. 

This project demonstrates installing Vault on an AWS EC2 instance, configuring an AppRole authentication engine, and writing ephemeral secrets directly to a secure S3 bucket. 

### PDF GUIDE: [CICD PIPELINE FOR IAC  WITH TERRAFORM.pdf](https://github.com/user-attachments/files/32192778/CICD.PIPELINE.FOR.IAC.WITH.TERRAFORM.pdf)



### WATCH VIDEO WALKTHROUGH HERE: https://youtu.be/XZa_F_jOxUs

## PREREQUISITES
AWS Account with permissions to manage EC2, Security Groups, IAM, and S3 resources.  
WSL2 / Linux Terminal on your local machine.  
Terraform CLI installed locally. 


## STEP-BY-STEP IMPLEMENTATION 

### Phase 1: SSH Key Management & WSL Setup

I) Log in to the AWS Management Console and create an EC2 Key Pair named vault_key_pair (download vault_key_pair.pem).  

II) Open your terminal (or WSL) and move the key pair to your hidden .ssh directory: 

<PRE>mkdir -p ~/.ssh</PRE>
<PRE>mv /mnt/c/Users/YOUR_USER/Downloads/vault_key_pair.pem ~/.ssh/</PRE>
<PRE>chmod 400 ~/.ssh/vault_key_pair.pem</PRE>


### Phase 2: EC2 Instance Provisioning

I) Launch an EC2 instance running Ubuntu Server named vault_instance using vault_key_pair.  

II) Under Network Settings, attach a Security Group named vault_SG allowing SSH (22), HTTP (80), and HTTPS (443).  

III) SSH into the EC2 instance using SSH agent forwarding:

<PRE>eval $(ssh-agent)</PRE>
<PRE>ssh-add ~/.ssh/vault_key_pair.pem</PRE>
<PRE>ssh -A ubuntu@<YOUR_EC2_PUBLIC_IPV4></PRE>


### Phase 3: Installing HashiCorp Vault

I) Run the following commands on your EC2 instance to add HashiCorp's GPG key and official repository:

<PRE>sudo apt update && sudo apt install gpg -y</PRE>
<PRE>wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg-dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg</PRE>
<PRE>gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint</PRE>
<PRE>echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list</PRE>
<PRE>sudo apt update && sudo apt install vault -y</PRE>


### Phase 4: Vault Dev Server Initialization

I) Start the Vault development server bound to port 8200:

2) In your AWS EC2 Console, update vault_SG by adding an Inbound Rule:
   Type: Custom TCP  Port: 8200
   Source: 0.0.0.0/0 (Anywhere IPv4)

3) Open a second terminal session, SSH back into your instance, and export the environment variable: 

4) Open <PRE>http://<YOUR_EC2_PUBLIC_IP>:8200</PRE> in your browser and sign in using the Root Token outputted in Terminal 1


### Phase 5: KV Engine & Secret Configuration

1) In the Vault UI, navigate to Secrets Engine -> Enable New Engine:

2) Choose KV (Key-Value), set the path to kvsecret, and click Enable Engine.

3) Inside kvsecret, click Create Secret:
   Path: sensitive-secrets
   Key: secret_id
   Value: 12345678910

4) Save the secret


### Phase 6: AppRole Authentication & Policy Setup
In your second terminal session, create the terraform policy and enable AppRole authentication:

1) Write Policy (terraform)_policy.tf. Access write policy from terraform_policy.tf file in repo.

2) Enable AppRole & Create Role:

<PRE>vault auth enable approle</PRE>
<PRE>vault write auth/approle/role/terraform secret_id_ttl=0 token_num_uses=0 token_ttl=0 token_max_ttl=0 secret_id_num_uses=0 token_policies=terraform</PRE>


3) Generate Credentials:

<PRE>vault read auth/approle/role/terraform/role-id</PRE>
<PRE>vault write -f auth/approle/role/terraform/secret-id</PRE>


### Phase 7: Terraform Integration & Execution

1) Create a workspace directory locally or on your third terminal session:

<PRE>mkdir vault && cd vault</PRE>

2) Write the main Terraform manifest (main.tf), use main.tf file in repo:


3) Deploy the resources:

<PRE>terraform init</PRE>
<PRE>terraform plan</PRE>
<PRE>terraform apply -auto-approve</PRE>


## VERIFICATION & STATE FILE AUDIT

1) Verify S3 Bucket Object:

<PRE>aws s3 ls</PRE>
<PRE>aws s3 ls s3://chinedu-secrets-bucket-<suffix>/secrets/</PRE>


2) Audit terraform.tfstate for Leaks:

<PRE>cat terraform.tfstate | grep "12345678910"</PRE>


## CLEANUP

1) To destroy all provisioned cloud resources and stop charges.

<PRE>terraform destroy -auto-approve</PRE>

