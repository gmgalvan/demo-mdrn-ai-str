# Terraform infrastructure

Demo infrastructure to deploy the network first and then a small EKS
cluster on AWS.

## Layers

- `backend/`: script to create the S3 bucket and DynamoDB table for the backend.
- `networking/`: VPC, public/private subnets, NAT Gateway and tags for EKS.
- `compute/`: EKS cluster and a small managed node group.
- `services/`: AWS resources for the app's services (today: the `payment-api`
  and `webui` ECR repositories where the CI workflows publish images).
  Independent of networking/compute, it can be applied at any time.
- `modules/`: local, reusable Terraform modules (`vpc`, `ecr`) consumed by
  the layers above. Copied from another project's module library and
  adapted here — see the comments in `modules/ecr/main.tf` and
  `networking/main.tf` for the tweaks specific to this repo.

## Requirements

- AWS CLI authenticated with permissions for S3, DynamoDB, EC2, IAM and EKS.
- Terraform `>= 1.6`.

## Usage

> The commands below use `terraform -chdir=<layer>`, which assumes you're
> standing in `infra/`. If you've already `cd`-ed into a layer folder
> (e.g. `infra/services/`), drop the `-chdir=<layer>` prefix and run the
> plain `terraform init/plan/apply` instead.

```bash
# 1. Create the remote backend and generate backend.dev.hcl in each layer
cd infra
./backend/bootstrap-backend.sh

# 2. Apply networking
terraform -chdir=networking init -backend-config=backend.dev.hcl
terraform -chdir=networking plan -out=networking.tfplan
terraform -chdir=networking apply networking.tfplan

# 3. Apply compute/EKS
terraform -chdir=compute init -backend-config=backend.dev.hcl
terraform -chdir=compute plan -out=compute.tfplan
terraform -chdir=compute apply compute.tfplan

# 4. Apply services (ECR; doesn't depend on networking/compute, can be done in parallel)
terraform -chdir=services init -backend-config=backend.dev.hcl
terraform -chdir=services plan -out=services.tfplan
terraform -chdir=services apply services.tfplan
```

To tear down, do it in reverse order:

```bash
terraform -chdir=compute destroy
terraform -chdir=networking destroy
terraform -chdir=services destroy
```

## Common variables

Each layer includes a `terraform.tfvars.example`. If you want to change the
region, CIDR, project name or node group size, copy the example:

```bash
cp networking/terraform.tfvars.example networking/terraform.tfvars
cp compute/terraform.tfvars.example compute/terraform.tfvars
cp services/terraform.tfvars.example services/terraform.tfvars
```
