# TP 01 — Docker et Minikube (Application Node.js)

## Objectif

Construire une image Docker légère pour une application web minimale en Node.js (`hello-node:1.0`), exécuter et tester le service dans un conteneur Docker isolé, puis déployer cette même image dans un cluster Kubernetes local Minikube (profil `intro-docker`) afin de comparer les deux modes de déploiement.

## Structure du dossier

```text
tp/01-docker-minikube-node/
├── README.md
└── node-docker
    ├── .dockerignore
    ├── Dockerfile
    ├── deployment.yaml
    └── server.js
```

## Prérequis

* **Système hôte :** Windows 10/11 avec PowerShell
* **Moteur de conteneurs :** Docker Desktop démarré en mode conteneurs Linux
* **Orchestrateur local :** Minikube (`v1.39+`) avec le pilote `docker`
* **Profil Kubernetes dédié :** `intro-docker`

## Procédure d'exécution

### 1. Scénario 1 — Construire l'image et exécuter sous Docker

Construire l'image `hello-node:1.0` à partir du contexte courant (`.`), démarrer le conteneur en reliant le port `8080` de l'hôte au port `3000` du conteneur, vérifier la réponse HTTP, puis supprimer le conteneur de test :

```powershell
docker build -t hello-node:1.0 .
docker run -d --name hello-node -p 127.0.0.1:8080:3000 hello-node:1.0
docker ps --filter name=hello-node
curl.exe -i http://127.0.0.1:8080
docker rm -f hello-node
```

### 2. Scénario 2 — Déployer l'image dans Minikube

Démarrer le cluster dédié `intro-docker`, charger l'image locale `hello-node:1.0` dans le registre interne du cluster et appliquer le manifeste `deployment.yaml` :

```powershell
minikube start -p intro-docker --driver=docker
minikube -p intro-docker image load hello-node:1.0
minikube -p intro-docker image ls
minikube -p intro-docker kubectl -- apply -f deployment.yaml
minikube -p intro-docker kubectl -- rollout status deployment/hello-node
minikube -p intro-docker kubectl -- get pods,services
```

### 3. Accéder au service Kubernetes depuis l'hôte

Établir un transfert de port local vers le Service `hello-node` (laisser ce terminal ouvert pendant le test) :

```powershell
minikube -p intro-docker kubectl -- port-forward service/hello-node 8080:8080
```

Dans un second terminal PowerShell (ou un navigateur web sur `http://127.0.0.1:8080`) :

```powershell
curl.exe -i http://127.0.0.1:8080
```

Arrêter ensuite le transfert de port avec `Ctrl + C`.

## Résultats attendus et preuves de vérification

### Exécution sous Docker (`docker ps` et réponse HTTP)

Le conteneur `hello-node` est actif (`Up`) et renvoie `HTTP/1.1 200 OK` avec le message attendu :

```text
> docker ps --filter name=hello-node
CONTAINER ID   IMAGE            COMMAND                  CREATED          STATUS         PORTS                      NAMES
d4f78f4811b3   hello-node:1.0   "docker-entrypoint.s…"   10 seconds ago   Up 9 seconds   127.0.0.1:8080->3000/tcp   hello-node
```
```text
> curl.exe -I http://127.0.0.1:8080
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-88
Date: Thu, 19 Nov 2026 09:45:20 GMT
Connection: keep-alive
Keep-Alive: timeout=5
```

### Déploiement sous Minikube (`get pods,services` et réponse HTTP identique)

Le Pod `hello-node` est `Running` (`1/1`), le Service `hello-node` est exposé sur `8080:30007/TCP`, et la requête sur `http://127.0.0.1:8080` retourne strictement le même résultat HTTP :

```text
> minikube -p intro-docker kubectl -- get pods,services
NAME                              READY   STATUS    RESTARTS   AGE
pod/hello-node-7dd869979d-dfr7x   1/1     Running   0          45s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/hello-node   NodePort    10.101.99.32   <none>        8080:30007/TCP   45s
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP          9m42s
```
```text
> minikube -p intro-docker service hello-node --url
http://127.0.0.1:49385
```
```text
> curl.exe -I http://127.0.0.1:49385
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-88
Date: Thu, 19 Nov 2026 09:49:35 GMT
Connection: keep-alive
Keep-Alive: timeout=5
```

## Analyse

### 1. Pourquoi Node.js n'a pas besoin d'être installé sur le poste ?

* **Encapsulation dans l'image Docker :** Le `Dockerfile` repose sur l'image de base officielle `node:24-alpine`, qui intègre déjà le moteur d'exécution Node.js (`node`) et ses bibliothèques système sur une base Alpine Linux légère.
* **Isolation et portabilité :** Le processus `node server.js` s'exécute à l'intérieur du conteneur isolé. Le poste hôte n'a besoin que du moteur Docker pour exécuter l'application dans un environnement identique et reproductible, sans dépendre d'une installation locale de Node.js.

### 2. Ce qui rend l'application accessible dans les deux scénarios

* **Dans le conteneur / Pod :** Le serveur HTTP écoute sur toutes les interfaces réseau (`0.0.0.0`) sur le port `3000` (`EXPOSE 3000` / `containerPort: 3000`).
* **Sous Docker seul (`docker run`) :** L'option `-p 127.0.0.1:8080:3000` met en place une redirection de port (*port mapping* / NAT) au niveau du moteur Docker entre le port `8080` de l'interface locale de l'hôte et le port `3000` du conteneur.
* **Sous Kubernetes / Minikube (`deployment.yaml`) :**
  * L'objet **Service** (`type: NodePort`) cible les Pods étiquetés `app: hello-node`, reçoit les requêtes sur le port `8080` et les route vers `targetPort: 3000` du Pod (tout en exposant le `nodePort: 30007` sur le nœud Minikube).
  * Le nœud Minikube tournant lui-même dans un conteneur Docker sous Windows, la commande `kubectl port-forward service/hello-node 8080:8080` crée un tunnel réseau local reliant `127.0.0.1:8080` sur l'hôte au Service dans le cluster.

### 3. Comparaison du cycle de vie : conteneur Docker seul vs Pod géré par un Deployment

| Critère | Conteneur Docker seul (`docker run`) | Pod géré par un `Deployment` Kubernetes |
| :--- | :--- | :--- |
| **Création et état** | Lancé impérativement ; aucun contrôleur ne surveille son état après démarrage. | Déclaré dans `deployment.yaml` (`replicas: 1`) ; un **ReplicaSet** maintient en permanence le nombre de répliques souhaité. |
| **Arrêt ou crash** | Le conteneur passe à l'état `Exited` et le service devient indisponible jusqu'à intervention manuelle. | **Auto-réparation (*self-healing*) :** en cas de crash ou de suppression (`delete pod`), le ReplicaSet recrée immédiatement un nouveau Pod. |
| **Contrôle de santé** | Docker vérifie uniquement que le processus principal (`PID 1`) est actif. | La `readinessProbe` (`httpGet` sur `/` port `3000`) valide que l'application répond en HTTP avant d'autoriser le routage du trafic. |
| **Exposition réseau** | Directement couplée à un conteneur unique. | Découplée via le **Service** (`selector: app: hello-node`), qui conserve une adresse et un port stables lors du remplacement des Pods. |

### 4. Relevés observés

* **État `Ready` du Pod :** `1/1` (`Running`, après validation de la `readinessProbe` sur `GET / :3000`).
* **Ports du Service `hello-node` :** `8080:30007/TCP` (port Service `8080`, `targetPort` `3000`, `nodePort` `30007`).
* **Message HTTP affiché :** `Hello, Docker and Minikube from Node.js!` (`HTTP/1.1 200 OK`, `Content-Type: text/plain; charset=utf-8`).

## Nettoyage

Supprimer les ressources Kubernetes déployées ainsi que le profil Minikube dédié :

```powershell
minikube -p intro-docker kubectl -- delete -f deployment.yaml
minikube delete -p intro-docker
```