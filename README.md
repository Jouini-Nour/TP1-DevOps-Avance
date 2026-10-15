# TP GitOps - Déploiement continu avec ArgoCD

## 🎯 Objectif
Mettre en place un pipeline GitOps de bout en bout avec **ArgoCD** pour automatiser le déploiement et la synchronisation d'une application sur Kubernetes.

---

## 📁 Structure du projet

```
TP1-DevOps-Avance/
├── kustomize-app/              # Manifests Kubernetes (Kustomize)
│   ├── base/                   # Ressources de base
│   │   ├── deployment.yaml     # Deployment Nginx
│   │   ├── service.yaml        # Service ClusterIP
│   │   ├── ingress.yaml        # Ingress rule
│   │   └── kustomization.yaml  # Configuration Kustomize
│   └── overlays/
│       └── dev/                # Overlay environnement Dev
│           └── kustomization.yaml
├── argocd-app/                 # Configuration ArgoCD
│   └── application.yaml        # Application CRD
├── demo-scenarios/             # Scripts de démonstration
│   ├── scenario1-deploy.sh
│   ├── scenario2-drift.sh
│   ├── scenario3-error.sh
│   └── scenario4-rollback.sh
├── init-cluster.sh             # Script d'initialisation complet
└── README.md                   # Ce fichier
```

---

## ⚙️ Prérequis

| Outil | Version minimale | Installation |
|-------|-----------------|--------------|
| Docker Desktop | 4.x+ | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| kubectl | 1.28+ | [kubernetes.io/docs/tasks/tools/install-kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/) |
| kind | 0.20+ | [kind.sigs.k8s.io/docs/user/quick-start/#install](https://kind.sigs.k8s.io/docs/user/quick-start/#install) |
| git | 2.40+ | [git-scm.com/downloads](https://git-scm.com/download/win) |
| Kustomize | intégré à kubectl | `kubectl version` >= 1.28 |

### Activation de Kubernetes dans Docker Desktop
1. Ouvrir **Docker Desktop**
2. Aller dans **Settings → General**
3. Cocher **"Use Kubernetes tools"**
4. Cliquer **Apply & Restart**
5. Vérifier : `kubectl cluster-info`

---

## 🚀 Démarrage rapide

### Étape 1 : Initialiser le cluster et déployer ArgoCD

```bash
# Rendre le script executable (Linux/Mac)
chmod +x init-cluster.sh

# Ou sous Windows (Git Bash)
bash init-cluster.sh
```

Ce script fait automatiquement :
- Crée un cluster Kind nommé `gitops-tp`
- Applique les manifests Kubernetes via Kustomize
- Installe ArgoCD v2.11.0
- Configure l'Application ArgoCD

### Étape 2 : Accéder à l'UI ArgoCD

```bash
# Port-forward vers ArgoCD UI
kubectl -n argocd port-forward svc/argocd-server 8080:443 &

# Mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Ouvrir **https://localhost:8080** dans votre navigateur et accepter le certificat auto-signé.

---

## Scénario 1 : Déploiement continu automatisé

**Objectif**: Montrer qu'un changement dans le dépôt Git est automatiquement appliqué au cluster Kubernetes via ArgoCD.

### Étapes à réaliser en démo:

```bash
# 1. Vérifier l'état initial (2 replicas, image nginx:1.27.0)
kubectl get deployment nginx-deployment -n gitops-namespace -o wide

# 2. Modifier l'image dans kustomize-app/base/deployment.yaml
#    Changer "nginx:1.27.0" → "nginx:1.27.1"

# 3. Commiter et push vers le repo Git
git add kustomize-app/base/deployment.yaml
git commit -m "chore: Update nginx image to 1.27.1"
git push origin main

# 4. Observer la synchronisation automatique d'ArgoCD (~60s)
kubectl get pods -n gitops-namespace -w
```

### Résultat attendu:
- ✅ ArgoCD détecte le changement Git après ~30 secondes
- ✅ Le sync se fait automatiquement (automated sync = true)
- ✅ Les pods sont redéployés avec la nouvelle image sans intervention manuelle
- ✅ Dans l'UI ArgoCD: Sync Status = **Synced**, Health Status = **Healthy**

---

## Scénario 2 : Configuration Drift & Self-Healing

**Objectif**: Montrer qu'ArgoCD détecte et corrige automatiquement toute modification manuelle non autorisée.

### Étapes à réaliser en démo:

#### Test A : Suppression du Deployment
```bash
# 1. Supprimer manuellement le deployment
kubectl delete deployment nginx-deployment -n gitops-namespace

# 2. Observer dans ArgoCD UI
#    - Sync Status passe OutOfSync -> corrigé automatiquement
#    - Le deployment est recréé en ~30-60s

# 3. Vérifier que le deployment a été restauré
kubectl get deployments -n gitops-namespace
```

#### Test B : Modification manuelle d'un label
```bash
# 1. Ajouter un label manuel qui n'est pas dans Git
kubectl label deployment/nginx-deployment manual-test=true \
  -n gitops-namespace --overwrite

# 2. Attendre ~60s que le self-heal retire ce label

# 3. Vérifier
kubectl get deployment nginx-deployment --show-labels
# Le label "manual-test" aura été retiré par ArgoCD ✓
```

### Résultat attendu:
- ✅ ArgoCD détecte le drift (différence entre cluster et Git)
- ✅ Auto-heal restaure l'état désiré automatiquement
- ✅ Le cluster revient à l'état déclaré dans Git

---

## Scénario 3 : Gestion des erreurs - Sync vs Health

**Objectif**: Prouver que **Synced ≠ Healthy**. Une application peut parfaitement synchronisée mais ne pas fonctionner.

### Étapes à réaliser en démo:

```bash
# 1. Introduire une erreur (image qui n'existe pas)
# Option A: Modifier directement dans le cluster
kubectl set image deployment/nginx-deployment \
  nginx=nourahmidi/tp1-nginx-app:v99.99.99 \
  -n gitops-namespace

# Option B: Modifier dans Git et laisser ArgoCD sync (si auto-sync actif)
#    Changer l'image dans deployment.yaml → nginx:nonexistent-tag
#    git add && git commit && git push
```

### Observations à montrer dans l'UI ArgoCD:

```bash
# Vérifications complémentaires
kubectl get pods -n gitops-namespace           # Pods en Error/CrashLoopBackOff
kubectl describe pod -n gitops-namespace       # ErrImagePull / ImagePullBackOff
```

| Concept | État observé | Signification |
|---------|-------------|---------------|
| **Sync Status** | `SYNCED` | Le manifest sur le cluster correspond exactement à Git |
| **Health Status** | `DEGRADED` ou `Error` | L'application ne fonctionne pas (image introuvable) |

### Résultat attendu:
- ✅ **Synced = OUI**: Pas de drift, configuration = celle de Git
- ✅ **Healthy = NON**: Pods en `ErrImagePull` / `ImagePullBackOff`
- ✅ **Conclusion clé**: Synchronisation ≠ Fonctionnement !

---

## Scénario 4 : Historique & Rollback rapide

**Objectif**: Revenir instantanément à une version stable depuis l'historique ArgoCD.

### Étapes à réaliser en démo (depuis l'UI):

1. **Ouvrir l'UI ArgoCD**: `https://localhost:8080`
2. **Cliquer sur** `nginx-gitops-app`
3. **Onglet "History"** - voir toutes les révisions précédentes
   - Revision actuelle (erreur, v99.99.99) ❌
   - Revision N-1 (stable) ✅
   - Revision N-2 (stable) ✅
4. **Cliquer sur** une révision stable précédente
5. **Cliquer sur le bouton "Rollback"**
6. **Vérifier**: Application redevenue Healthy en quelques secondes

### Ou via CLI:
```bash
# Voir l'historique des syncs
argocd app history nginx-gitops-app -n argocd

# Exécuter le rollback
argocd app rollback nginx-gitops-app <ID_REVOLUTION> -n argocd

# Vérifier que tout est redevenu OK
kubectl get pods -n gitops-namespace
```

### Résultat attendu:
- ✅ L'application redevient **Healthy** immédiatement
- ✅ La configuration redevient **Synced**
- ✅ Un nouvel historique est ajouté (rollback comme nouvelle action)
- ✅ Retour à l'image/stabilité précédente en < 1 minute

---

## 📚 Concepts GitOps illustrés

| Concept | Implémentation dans ce TP | Commande pour vérifier |
|---------|---------------------------|------------------------|
| **SSOT (Single Source of Truth)** | Fichiers Kustomize dans Git | `cat kustomize-app/base/deployment.yaml` |
| **GitOps Pull-based** | ArgoCD tourne DANS le cluster | `kubectl get pods -n argocd` |
| **Self-Healing** | `spec.syncPolicy.automated.selfHeal: true` | Scénario 2 |
| **Auto-Prune** | Ressources supprimées si retirées de Git | `prune: true` dans config |
| **Sync vs Health** | Deux états indépendants | Scénario 3 |
| **Rollback facile** | Historique complet + 1 clic | Scénario 4 |

---

## 🔧 Commandes utiles pour debugging

```bash
# Vérifier l'état de l'application ArgoCD
kubectl get application nginx-gitops-app -n argocd -o yaml

# Voir l'historique des syncs
argocd app history nginx-gitops-app -n argocd

# Forcer une resync (si auto-sync désactivé temporairement)
kubectl apply -f argocd-app/application.yaml
# OU
argocd app sync nginx-gitops-app -n argocd

# Logs ArgoCD
kubectl logs -n argocd deploy/argocd-application-controller -f

# Événements Kubernetes
kubectl get events -n gitops-namespace --sort-by='.lastTimestamp'

# Décrire un pod problématique
kubectl describe pod -l app=nginx -n gitops-namespace
```

---

## 🎯 Critères d'évaluation

| Critère | Statut |
|---------|--------|
| Dépôt Git avec manifests Kustomize structurés | ✅ À réaliser |
| ArgoCD installé et opérationnel | ✅ À réaliser |
| Application ArgoCD configurée | ✅ À réaliser |
| Auto-sync activé (`automated.sync + selfHeal`) | ✅ À réaliser |
| Scénario 1 : Deploy automatique fonctionnel | ✅ À démontrer |
| Scénario 2 : Drift détecté + Self-Healing | ✅ À démontrer |
| Scénario 3 : Distinction Sync/Health prouvée | ✅ À démontrer |
| Scénario 4 : Rollback réussi | ✅ À démontrer |

---

## ⚠️ Précautions importantes

1. **Docker Desktop DOIT être démarré** avant d'exécuter les scripts
2. Le cluster Kind est **local** — parfait pour tests/démo
3. Pour production : remplacer repo local par GitHub/GitLab privé
4. Les credentials ArgoCD sont dans un Secret Kubernetes
5. Ne jamais supprimer directement les ressources pendant un déploiement

---

## 🐛 Résolution de problèmes courants

### ArgoCD ne démarre pas
```bash
# Vérifier les pods
kubectl get pods -n argocd

# Redémarrer si nécessaire
kubectl rollout restart deployment -n argocd argocd-server
```

### Application reste OutOfSync
```bash
# Forcer le sync
kubectl apply -f argocd-app/application.yaml
# OU
argocd app sync nginx-gitops-app -n argocd
```

### Pods en CrashLoopBackOff
```bash
# Vérifier les logs
kubectl logs -l app=nginx -n gitops-namespace
# Vérifier les events
kubectl describe deployment nginx-deployment -n gitops-namespace
```
