# Terraform infrastructure

Infraestructura demo para desplegar primero la red y despues un cluster EKS
pequeno en AWS.

## Capas

- `backend/`: script para crear el bucket S3 y la tabla DynamoDB del backend.
- `networking/`: VPC, subnets publicas/privadas, NAT Gateway y tags para EKS.
- `compute/`: cluster EKS y un managed node group pequeno.
- `services/`: recursos de AWS para los servicios de la app (hoy: repositorios
  ECR `payment-api` y `webui` donde los workflows de CI publican las
  imagenes). Independiente de networking/compute, se puede aplicar en
  cualquier momento.

## Requisitos

- AWS CLI autenticado con permisos para S3, DynamoDB, EC2, IAM y EKS.
- Terraform `>= 1.6`.

## Uso

```bash
# 1. Crear backend remoto y generar backend.dev.hcl en cada capa
cd infra
./backend/bootstrap-backend.sh

# 2. Aplicar networking
terraform -chdir=networking init -backend-config=backend.dev.hcl
terraform -chdir=networking plan -out=networking.tfplan
terraform -chdir=networking apply networking.tfplan

# 3. Aplicar compute/EKS
terraform -chdir=compute init -backend-config=backend.dev.hcl
terraform -chdir=compute plan -out=compute.tfplan
terraform -chdir=compute apply compute.tfplan

# 4. Aplicar services (ECR; no depende de networking/compute, se puede hacer en paralelo)
terraform -chdir=services init -backend-config=backend.dev.hcl
terraform -chdir=services plan -out=services.tfplan
terraform -chdir=services apply services.tfplan
```

Para destruir, hazlo en orden inverso:

```bash
terraform -chdir=compute destroy
terraform -chdir=networking destroy
terraform -chdir=services destroy
```

## Variables comunes

Cada capa incluye `terraform.tfvars.example`. Si quieres cambiar region, CIDR,
nombre de proyecto o tamano del node group, copia el ejemplo:

```bash
cp networking/terraform.tfvars.example networking/terraform.tfvars
cp compute/terraform.tfvars.example compute/terraform.tfvars
cp services/terraform.tfvars.example services/terraform.tfvars
```

