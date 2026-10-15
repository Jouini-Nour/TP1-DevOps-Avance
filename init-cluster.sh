#!/bin/bash
# =============================================================================
# Script d'initialisation complet pour le TP GitOps avec ArgoCD
# =============================================================================
set -e

echo "================================================"
echo "  INITIALISATION du TP GitOps - ArgoCD"
echo "================================================"
echo ""

echo "[ETAPES] Verification des prerequis..."

if ! command -v kubectl &> /dev/null; then
    echo "[ERREUR] kubectl n'est pas installe"
    exit 1
fi

if ! command -v kind &> /dev/null; then
    echo "[ERREUR] kind n'est pas installe"
    exit 1
fi

if ! docker ps &> /dev/null; then
    echo "[ERREUR] Docker n'est pas en cours d'execution"
    echo "   Veuillez demarrer Docker Desktop et reessayer."
    exit 1
fi

# Verifier si le cluster existe deja
if kind get clusters | grep -q "gitops-tp"; then
    echo "[AVERTISSEMENT] Le cluster 'gitops-tp' existe deja."
else
    echo "[INFO] Creation du cluster Kind..."
    kind create cluster --name gitops-tp --wait 120s
fi

echo "[SUCCES] Cluster pret !"
kubectl cluster-info
echo ""

# ----------------------------------------
# ETAPES 1: Appliquer les manifests via Kustomize
# ----------------------------------------
echo "[ETAPES] Creation du namespace gitops-namespace..."
kubectl create namespace gitops-namespace --dry-run=client -o yaml | kubectl apply -f -
sleep 2

echo "[ETAPES] Application des manifests Kubernetes via Kustomize..."
kustomize build kustomize-app/base/ | kubectl apply -f -

echo "[SUCCES] Manifests appliques !"
echo ""

echo "--- Deployments ---"
kubectl get deployments -n gitops-namespace
echo "--- Services ---"
kubectl get services -n gitops-namespace
echo "--- Pods ---"
kubectl get pods -n gitops-namespace
echo ""

# ----------------------------------------
# ETAPES 2: Installer ArgoCD (version stable)
# ----------------------------------------
echo "[ETAPES] Installation d'ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
sleep 1

echo "   Installation d'ArgoCD v2.11.0 (stable)..."
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.0/manifests/install.yaml" --force-conflicts=true

echo "   Attente du deploiement d'ArgoCD (~90s)..."
sleep 90

echo ""
echo "--- Verification du deploiement ArgoCD ---"
kubectl get pods -n argocd

echo "   Attente des pods ArgoCD..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s 2>/dev/null || true
sleep 10

ARGOCD_ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "(non disponible)")

echo ""
echo "================================================"
echo "  INITIALISATION TERMINÉE AVEC SUCCÈS!"
echo "================================================"
echo ""
echo "🔐 Connexion à ArgoCD :"
echo "   URL Web UI : https://localhost:8080 (accepter certificat)"
echo "   Username : admin"
echo "   Password : ${ARGOCD_ADMIN_PASSWORD}"
echo ""
echo "Commande pour acceder a l'UI :"
echo "   kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo ""
echo "Prochaines etapes pour les demonstrations :"
echo "  1. Ouvrir Docker Desktop avec Kubernetes active"
echo "  2. Executer: bash ./init-cluster.sh"
echo "  3. Configurer le port-forward vers ArgoCD"
echo "  4. Suivre le README.md pour les 4 scenarios de demo"
echo ""
echo "================================================"
echo ""

# ETAPESUITE
