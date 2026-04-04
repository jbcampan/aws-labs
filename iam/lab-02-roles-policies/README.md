# lab-02-roles-policies

## Objectif

Comprendre et pratiquer les rôles IAM, les policies custom et le mécanisme `AssumeRole` via STS dans AWS — en suivant le principe de least-privilege.

Ce lab couvre la création d'une policy custom en JSON, d'un rôle IAM avec cette policy attachée, et l'utilisation de credentials temporaires via `sts:AssumeRole` pour accéder à un bucket S3.

---

## Ce que ce lab déploie

- **1 S3 Bucket** : `mon-bucket-unique` (avec un objet de test `hello.txt`)
- **3 IAM Users** : `user1`, `user2`, `user3`
- **1 IAM Policy custom** : `readonly-s3-policy` (read-only sur le bucket spécifique uniquement)
- **1 IAM Role** : `readonly-role` avec la policy attachée
- **1 `assume_role_policy`** : définit qui peut assumer le rôle

---

## Ce qu'on apprend

- Écrire une **policy JSON custom** à la main (Resource ARN spécifique, actions précises)
- La différence entre **identity-based policy** (attachée à un user/role) et **resource-based policy** (attachée à la ressource, ex: bucket policy S3)
- Le mécanisme **`AssumeRole` + STS** (credentials temporaires) — fondamental en entretien
- Le principe de **least-privilege** concrètement appliqué : accès read-only sur un bucket spécifique, pas sur tous
- Séparer les valeurs sensibles du code via `terraform.tfvars`

---

## Structure

```
lab-02-roles-policies/
├── terraform/
│   ├── main.tf                  # Bucket S3, users IAM, policy custom, rôle, attachement
│   ├── variables.tf             # Users, région, nom du bucket, account ID
│   ├── outputs.tf               # ARN du rôle, nom du bucket, noms des users
│   ├── providers.tf             # Provider AWS (~> 5.0), région configurable
│   ├── terraform.tfvars         # Valeurs sensibles (non commité)
│   └── terraform.tfvars.example # Template à copier pour configurer le lab
├── scripts/
│   ├── roles-policies-terraform.sh   # Init + apply + export outputs + lancement Python
│   └── assume-role.py               # AssumeRole via STS + accès S3 avec credentials temporaires
└── README.md
```

---

## Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configuré (`aws configure`)
- Python 3 avec `boto3` installé (`pip install boto3`)
- Droits IAM suffisants pour créer des users, rôles, policies et buckets S3

---

## Configuration

1. Copier le fichier d'exemple :

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

2. Remplir les valeurs dans `terraform/terraform.tfvars` :

```hcl
aws_account_id = "123456789012"   # Votre AWS Account ID
mybucket       = "mon-bucket-unique"
```

---

## Utilisation

### Option 1 — Via le script (recommandé)

Le script enchaîne automatiquement `terraform apply` puis le script Python :

```bash
chmod +x scripts/roles-policies-terraform.sh
bash scripts/roles-policies-terraform.sh
```

### Option 2 — Manuellement

```bash
cd terraform/
terraform init
terraform plan
terraform apply

export ROLE_ARN=$(terraform output -raw role_arn)
export BUCKET_NAME=$(terraform output -raw bucket_name)

python3 ../scripts/assume-role.py
```

---

## Vérification post-déploiement

```bash
# Vérifier les policies attachées au rôle
aws iam list-attached-role-policies --role-name readonly-role

# Vérifier l'assume_role_policy du rôle
aws iam get-role --role-name readonly-role

# Lister les objets dans le bucket
aws s3 ls s3://mon-bucket-unique
```

---

## Personnalisation

Les users sont définis dans `variables.tf` :

```hcl
variable "users" {
  default = {
    user1 = "developers"
    user2 = "developers"
    user3 = "readonly"
  }
}
```

Le nom du bucket et l'account ID sont à renseigner dans `terraform.tfvars` (voir section Configuration).

---

## Nettoyage

```bash
cd terraform/
terraform destroy
```

---

## Coût

**0 $** — Les ressources IAM sont gratuites. Le bucket S3 et l'objet de test génèrent un coût négligeable (quelques fractions de centime le temps du lab).