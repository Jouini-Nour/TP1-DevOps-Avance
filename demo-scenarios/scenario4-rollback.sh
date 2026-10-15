#!/bin/bash
# =============================================================================
# Scénario 4 : Historique & Rollback rapide
# Objectif : Revenir à une version stable avec un clic depuis l'UI ArgoCD
# =============================================================================

echo "========================================"
echo "Scénario 4 : Rollback vers version stable"
echo "========================================"
echo ""

if ! kind get clusters | grep -q "gitops-tp"; then
    echo "[ERREUR] Le cluster 'gitops-tp' n'existe pas."
    exit 1
fi

echo "[INFO] Application actuellement Degraded (image inexistante)..."
echo ""
kubectl get deployment nginx-deployment -n gitops-namespace
kubectl get pods -n gitops-namespace
echo ""

echo "[ATTENTION]"
echo "   Si vous avez fait le Scenario 3, l'app estDegradée"
echo "   Sinon, mettons une image erronée maintenant..."
echo ""

kubectl set image deployment/nginx-deployment \
  nginx=nourahmidi/tp1-nginx-app:v99.99.99 \
  -n gitops-namespace --record 2>/dev/null || true

sleep 10

echo ""
echo "═══════════════════════════════════════"
echo "  🖥️  ACTIONS A FAIRE EN DIRECT DEVANT L'UI ArgoCD  🖥️"
echo "═══════════════════════════════════════"
echo ""
echo "  1. Ouvrir l'UI ArgoCD :"
echo "     kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "     Aller sur https://localhost:8080"
echo ""
echo "  2. Cliquer sur 'nginx-gitops-app'"
echo ""
echo "  3. Cliquer sur l'onglet 'History'"
echo ""
echo "  4. Vous verrez l'historique des révisions :"
echo "     - Revision X (erronée - v99.99.99)"
echo "     - Revision X-1 (stable)"
echo "     - Revision X-2 (stable)"
echo ""
echo "  5. Cliquer sur la révision précédente stable"
echo ""
echo "  6. Cliquer sur le bouton 'Rollback'"
echo ""
echo "═══════════════════════════════════════"
echo ""

echo "[ATTENTE] Le rollback s'execute automatiquement..."
sleep 20

echo ""
echo "[VERIFICATION] Etat après rollback :"
kubectl get deployment nginx-deployment -n gitops-namespace
kubectl get pods -n gitops-namespace
echo ""

echo "[SUCCES] L'application doit être redevenue Healthy !"
echo ""
echo "Dans l'UI ArgoCD, verifier :"
echo "  - Health Status = HEALTHY ✓"
echo "  - Sync Status = SYNCED ✓"
echo "  - Une nouvelle revision d'histoire a été crée"
echo "  - Le rollout du rollback est en cours ou terminé"
echo ""
echo "========================================"
echo "Fin du Scénario 4"
echo "  Rollback réussi en quelques secondes"
echo "  via l'interface ArgoCD ! ✓"
echo "========================================"