# lab-01-users-groups

## Objectif

Comprendre et pratiquer la gestion des identités humaines dans AWS IAM via Terraform.

Ce lab couvre la création d'utilisateurs IAM, leur organisation en groupes, et l'attachement de policies AWS managées aux groupes — en suivant la bonne pratique qui consiste à ne jamais attacher de policy directement à un utilisateur.

---

## Ce que ce lab déploie

- **3 IAM Users** : `user1`, `user2`, `user3`
- **2 IAM Groups** : `developers`, `readonly`
- **2 Policy attachments** (AWS managées) :
  - `developers` → `AmazonEC2FullAccess`
  - `readonly` → `AmazonS3ReadOnlyAccess`
- **3 Memberships** :
  - `user1` → `developers`
  - `user2` → `developers`
  - `user3` → `readonly`

---

## Ce qu'on apprend

- La différence entre attacher une policy **directement à un user** vs **via un groupe** (bonne pratique : toujours passer par les groupes)
- L'utilisation des **policies AWS managées** via leur ARN
- La hiérarchie `user → group → policy`
- L'utilisation de `for_each` avec `toset()` pour éviter les doublons dans Terraform

---

## Structure

```
lab-01-users-groups/
├── terraform/
│   ├── main.tf          # Ressources IAM (users, groups, memberships, policy attachments)
│   ├── variables.tf     # Map users → groupes, région AWS
│   ├── outputs.tf       # Noms des users et groupes créés
│   └── providers.tf     # Provider AWS (~> 5.0), région configurable
├── script/
│   └── users-groups-terraform.sh   # Init + apply automatisé
└── README.md
```

---

## Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- AWS CLI configuré (`aws configure`)
- Droits IAM suffisants pour créer des users, groupes et attacher des policies

---

## Utilisation

### Option 1 — Via le script

```bash
chmod +x script/users-groups-terraform.sh
./script/users-groups-terraform.sh
```

### Option 2 — Manuellement

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

---

## Vérification post-déploiement

```bash
# Lister les users créés
aws iam list-users

# Vérifier les groupes d'un user
aws iam list-groups-for-user --user-name user1

# Lister les policies attachées à un groupe
aws iam list-attached-group-policies --group-name developers
```

---

## Personalisation

Les users et leurs groupes sont définis dans `variables.tf` :

```hcl
variable "users" {
  default = {
    user1 = "developers"
    user2 = "developers"
    user3 = "readonly"
  }
}
```

Pour ajouter un user, il suffit d'ajouter une entrée dans cette map. Si le groupe n'existe pas encore, Terraform le crée automatiquement grâce au `toset()` sur les valeurs.

---

## Nettoyage

```bash
cd terraform/
terraform destroy
```

---

## Coût

**0 $** — Les ressources IAM sont gratuites sur AWS.