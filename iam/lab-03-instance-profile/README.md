# lab-03-instance-profile

## Objectif

Comprendre comment une ressource AWS (EC2) obtient des permissions sans credentials hardcodés.

Ce lab couvre la création d'une policy IAM custom, d'un rôle IAM, d'un instance profile, et leur association à une instance EC2 — permettant à l'instance de lire et écrire sur S3 sans aucune clé AWS configurée.

---

## Ce que ce lab déploie

- **1 S3 Bucket** avec un fichier `hello.txt` pré-existant
- **1 IAM Policy custom** : lecture/écriture sur le bucket S3 spécifique
- **1 IAM Role** : avec une trust policy autorisant `ec2.amazonaws.com` à l'assumer
- **2 Policy attachments** :
  - Rôle → policy S3 custom
  - Rôle → `AmazonSSMManagedInstanceCore` (accès Session Manager)
- **1 Instance Profile** : wrapper EC2 autour du rôle IAM
- **1 Instance EC2** : Ubuntu 22.04, avec l'instance profile attaché

---

## Ce qu'on apprend

- Pourquoi on ne met jamais de credentials AWS dans une instance EC2 (ni hardcodés, ni `aws configure`)
- Comment boto3 et la CLI AWS résolvent automatiquement les credentials via le **metadata service** (`169.254.169.254`) quand un instance profile est présent
- La distinction **rôle / instance profile** — le rôle définit les permissions, l'instance profile est le conteneur qu'EC2 attend
- Pourquoi les deux ARN (`bucket` et `bucket/*`) sont nécessaires dans une policy S3
- L'accès à une instance EC2 via **Session Manager** (sans clé SSH, sans port 22 ouvert)

---

## Flux d'obtention des credentials

```
EC2 démarre
  → contacte le metadata service (169.254.169.254)
  → récupère des credentials temporaires associés au rôle IAM
  → AWS autorise les appels S3 via ces credentials
```

Aucune clé AWS n'est configurée sur l'instance — tout est résolu automatiquement.

---

## Structure

```
lab-03-instance-profile/
├── terraform/
│   ├── main.tf           # S3, IAM policy, rôle, instance profile, EC2
│   ├── variables.tf      # Région, nom du bucket, type d'instance
│   ├── outputs.tf        # ARN et nom du rôle, nom du bucket
│   ├── providers.tf      # Provider AWS (~> 5.0)
│   └── terraform.tfvars  # Valeurs : bucket name, account id
├── script/
│   ├── instance-profile-terraform.sh  # Init + apply automatisé
│   └── test-s3.sh                     # Script de test à lancer depuis l'instance
└── README.md
```

---

## Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configuré (`aws configure`)
- Droits IAM suffisants pour créer des ressources IAM, EC2 et S3

---

## Utilisation

### Option 1 — Via le script

```bash
chmod +x script/instance-profile-terraform.sh
./script/instance-profile-terraform.sh
```

### Option 2 — Manuellement

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

---

## Test depuis l'instance

1. Console AWS → **EC2 → Instances** → sélectionne `lab03-instance-profile`
2. Bouton **Connect** → onglet **Session Manager** → **Connect**
3. Dans le terminal, installe la CLI AWS :

```bash
sudo apt update && sudo apt install -y awscli
```

4. Lance le script de test :

```bash
bash test-s3.sh
```

Le script valide la lecture, l'écriture et affiche la source des credentials.
La colonne `Type` de `aws configure list` doit afficher `iam-role` — preuve qu'aucune clé n'est configurée sur l'instance.

---

## Personnalisation

Le nom du bucket est défini dans `terraform.tfvars` :

```hcl
mybucket = "nom-unique-de-mon-bucket"
```

Pense à mettre à jour la variable `BUCKET` dans `script/test-s3.sh` avec la même valeur.

---

## Nettoyage

```bash
cd terraform/
terraform destroy
```

`force_destroy = true` est activé sur le bucket — Terraform le videra automatiquement même s'il contient des objets créés pendant le test.

---

## Coût

Quelques centimes — instance EC2 t3.micro (free tier éligible). Détruire l'instance juste après le test suffit à limiter les frais.