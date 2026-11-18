# Atelier A5 — Déployer Nginx avec Minikube

## Objectif

Démarrer un cluster Kubernetes local dédié avec Minikube (profil `infra-si`), déployer un serveur web `nginx:1.28-alpine`, l'exposer via un Service Kubernetes, vérifier son accessibilité depuis le poste hôte et observer le mécanisme d'auto-réparation (recréation automatique d'un Pod par le ReplicaSet après suppression).

## Structure du dossier

```text
ateliers/a5-nginx-minikube/
├── README.md
└── nginx-deployment.yaml
```

## Prérequis

* **Système hôte :** Windows 10/11 avec PowerShell
* **Moteur de conteneurs :** Docker Desktop démarré en mode conteneurs Linux
* **Orchestrateur local :** Minikube (`v1.39+`)
* **Profil Kubernetes dédié :** `infra-si` (pilote `docker`)

## Procédure d'exécution

### 1. Démarrer le cluster Minikube et vérifier le nœud

```bash
minikube start -p infra-si --driver=docker
minikube -p infra-si kubectl -- get nodes
```

### 2. Déployer Nginx et l'exposer via un Service

*(Peut être exécuté de manière impérative comme ci-dessous, ou de manière déclarative avec `minikube -p infra-si kubectl -- apply -f nginx-deployment.yaml`)* :

```bash
minikube -p infra-si kubectl -- create deployment nginx --image=nginx:1.28-alpine
minikube -p infra-si kubectl -- rollout status deployment/nginx --timeout=120s
minikube -p infra-si kubectl -- expose deployment nginx --port=80
minikube -p infra-si kubectl -- get pods,services
```

### 3. Tester l'accès HTTP depuis l'hôte

Ouvrir un tunnel local vers le Service Kubernetes (garder ce terminal actif pendant le test) :

```bash
minikube -p infra-si kubectl -- port-forward service/nginx 8090:80
```

Dans un second terminal PowerShell (ou un navigateur web sur `http://127.0.0.1:8090`) :

```powershell
curl.exe -I http://127.0.0.1:8090
```

Arrêter ensuite le `port-forward` avec `Ctrl + C`.

### 4. Observer le remplacement automatique d'un Pod

Supprimer le Pod actif et constater qu'un nouveau Pod est immédiatement recréé par le ReplicaSet pour maintenir l'état désiré (1 réplique) :

```bash
minikube -p infra-si kubectl -- get pods
minikube -p infra-si kubectl -- delete pod <NOM_DU_POD>
minikube -p infra-si kubectl -- get pods
```

## Résultats attendus et preuves de vérification

### État du cluster (`get nodes`)

Le nœud `infra-si` est actif et prêt (`Ready`) :

```text
> minikube -p infra-si kubectl -- get nodes
> kubectl.exe.sha256:  64 B / 64 B [---------------------] 100.00% ? p/s 0s
> kubectl.exe:  9.92 MiB / 60.52 MiB [--->_________________] 16.39% ? p/    
> kubectl.exe:  22.70 MiB / 60.52 MiB [------->____________] 37.51% ? p/    
> kubectl.exe:  33.50 MiB / 60.52 MiB [----------->________] 55.35% ? p/    
> kubectl.exe:  43.08 MiB / 60.52 MiB [---->__] 71.18% 55.24 MiB p/s ETA    
> kubectl.exe:  55.00 MiB / 60.52 MiB [------>] 90.88% 55.24 MiB p/s ETA    
> kubectl.exe:  60.52 MiB / 60.52 MiB [--------] 100.00% 67.59 MiB p/s 1.1s
NAME       STATUS   ROLES           AGE    VERSION
infra-si   Ready    control-plane   108s   v1.37.0
```

### Déploiement et exposition (`get pods,services` et test HTTP)

Le Pod `nginx` est en état `Running` (`1/1`), le Service `nginx` expose le port `80/TCP` et l'accès via `http://127.0.0.1:8090` retourne `HTTP/1.1 200 OK` :

```text
> curl.exe -I http://127.0.0.1:8090
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Wed, 18 Nov 2026 14:43:41 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 24 Mar 2026 19:45:11 GMT
Connection: keep-alive
ETag: "69c2e9c7-267"
Accept-Ranges: bytes
```

### Auto-réparation après suppression du Pod (`delete pod`)

Après suppression du Pod initial, un nouveau Pod avec un identifiant distinct est automatiquement démarré (`Running`) :
```text
> minikube -p infra-si kubectl -- get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-8487486ff9-nfs6j   1/1     Running   0          3m56s
```
```text
> minikube -p infra-si kubectl -- delete pod nginx-8487486ff9-nfs6j
pod "nginx-8487486ff9-nfs6j" deleted from default namespace
```
```text
> minikube -p infra-si kubectl -- get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-8487486ff9-pk2zj   1/1     Running   0          7s
```

## Nettoyage

Supprimer le profil de laboratoire Minikube une fois les vérifications terminées :

```bash
minikube delete -p infra-si
```