# TP 03 — OpenTofu avancé : Plateforme DevSecOps et Supervision locale

## 1. Objectif et architecture

Ce laboratoire met en œuvre deux environnements locaux indépendants déclarés avec **OpenTofu** (`kreuzwerker/docker`), illustrant l'usage des boucles `for_each`, des blocs `dynamic`, de la gestion de réseaux isolés, des volumes persistants et des contrôles de santé (`healthcheck`).

### Arborescence du dépôt

```text
03-opentofu-avance/
├── devsecops/               # Atelier 1 : Gitea, Jenkins, SonarQube, PostgreSQL
│   ├── versions.tf
│   └── main.tf
├── supervision/             # Atelier 2 : Node.js, Prometheus, Grafana, Loki, Alloy
│   ├── versions.tf
│   ├── main.tf
│   ├── app.js
│   ├── prometheus.yml
│   ├── loki.yaml
│   └── config.alloy
└── README.md
```

> **Note importante :** Les deux plateformes utilisent chacune les ports locaux `3000` et `8080`. Elles doivent être déployées séquentiellement (destruction propre de la première avant le démarrage de la seconde).

---

## 2. Prérequis

* **Moteur de conteneurs :** Docker Desktop en mode conteneurs Linux (~8 Go de RAM recommandés pour SonarQube et Jenkins).
* **Provisionnement :** OpenTofu (`tofu`) installé dans le `PATH`.
* **Paramètres noyau Linux (requis par Elasticsearch embarqué dans SonarQube) :**
  * `vm.max_map_count >= 524288`
  * `fs.file-max >= 131072`

### Vérification et ajustement des paramètres noyau (Windows / WSL2)

```powershell
# Vérifier les valeurs actuelles du moteur Linux
docker run --rm alpine:3.22 cat /proc/sys/vm/max_map_count /proc/sys/fs/file-max

# Ajuster vm.max_map_count sur le moteur WSL2 de Docker Desktop si inférieur à 524288
wsl -d docker-desktop sh -c "sysctl -w vm.max_map_count=524288"
```

---

## 3. Atelier 1 — Plateforme DevSecOps locale (`devsecops/`)

### Services déployés (réseau `devops-net`)

| Service | Image | URL / Port local | Stockage persistant |
| :--- | :--- | :--- | :--- |
| **Gitea** | `gitea/gitea:1.25` | `http://localhost:3000` | Volume `devops-gitea` (`/data`, SQLite3) |
| **Jenkins** | `jenkins/jenkins:lts-jdk21` | `http://localhost:8080` | Volume `devops-jenkins` (`/var/jenkins_home`) |
| **SonarQube** | `sonarqube:community` | `http://localhost:9000` | Volumes `devops-sonar`, `devops-plugins`, `devops-logs` |
| **PostgreSQL** | `postgres:16-alpine` | `127.0.0.1:5432` | Volume `devops-postgres` (`/var/lib/postgresql/data`) |

### Déploiement et vérifications

```powershell
cd 03-opentofu-avance\devsecops

tofu init
tofu fmt
tofu validate
tofu plan -out devops.tfplan
tofu show devops.tfplan
tofu apply devops.tfplan

# Vérifier que les 4 conteneurs sont actifs
docker ps -a --filter name=devops-
```

#### Contrôles fonctionnels effectués :
1. **PostgreSQL & SonarQube (`http://localhost:9000`) :**
   * Contrôle de disponibilité de la base : `docker exec devops-postgres pg_isready -h 127.0.0.1 -U sonar -d sonar` (`accepting connections`).
   * Statut de l'API SonarQube : `curl.exe -s http://localhost:9000/api/system/status` (`{"status":"UP"}`) et changement du mot de passe administrateur initial.
2. **Jenkins (`http://localhost:8080`) :**
   * Récupération du mot de passe d'amorçage en local (non publié dans le dépôt) via `docker exec devops-jenkins cat /var/jenkins_home/secrets/initialAdminPassword` et validation de l'accès à l'interface.
3. **Gitea (`http://localhost:3000`) et persistance :**
   * Initialisation SQLite3, création d'un utilisateur administrateur et d'un dépôt de test, redémarrage du conteneur (`docker restart devops-gitea`) et confirmation que le dépôt est conservé.
4. **Stabilité de l'état OpenTofu :**
   * `tofu plan` confirme `No changes. Your infrastructure matches the configuration.`

### Preuves de fonctionnement (Atelier 1)

```text
> docker ps -a --filter name=devops-
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS                    PORTS                      NAMES
ba6459a4aab5   74401de6a6f9   "/usr/bin/tini -- /u…"   13 seconds ago   Up 11 seconds             127.0.0.1:8080->8080/tcp   devops-jenkins
8e8ffcd40bd7   65541accbdb9   "/opt/sonarqube/dock…"   13 seconds ago   Up 11 seconds             127.0.0.1:9000->9000/tcp   devops-sonar
42e002791074   f846d26a4fc3   "/usr/bin/entrypoint…"   13 seconds ago   Up 11 seconds             127.0.0.1:3000->3000/tcp   devops-gitea
1feda7699c53   1d5b02d3a994   "docker-entrypoint.s…"   41 seconds ago   Up 40 seconds (healthy)   127.0.0.1:5432->5432/tcp   devops-postgres
```
```text
> docker exec devops-postgres pg_isready -h 127.0.0.1 -U sonar -d sonar
127.0.0.1:5432 - accepting connections
```
```text
> curl.exe -s http://localhost:9000/api/system/status
{"id":"46AF5D23-AaHz0r1L04D1JqKZ-h72","version":"26.11.0.134175","status":"UP"}
```
```text
> tofu plan

No changes. Your infrastructure matches the configuration.
```

### Nettoyage de l'environnement DevSecOps

```powershell
tofu plan -destroy -out devops-destroy.tfplan
tofu show devops-destroy.tfplan
tofu apply devops-destroy.tfplan
docker ps -a --filter name=devops-
```

---

## 4. Atelier 2 — Supervision d'une application locale (`supervision/`)

### Architecture et flux de télémétrie (réseau `monitoring-net`)

* **Métriques (Pull) :** `Prometheus` (`:9090`) interroge toutes les 5 secondes l'endpoint `/metrics` de l'`Application Node.js` (`:8080`).
* **Journaux (Push) :** L'`Application Node.js` écrit ses accès HTTP au format JSON dans `/logs/http.log` (volume partagé `monitoring-app_logs`) ; `Grafana Alloy` lit ce fichier en lecture seule et expédie les entrées vers `Loki` (`:3100`).
* **Visualisation :** `Grafana` (`:3000`) interroge simultanément `http://prometheus:9090` et `http://loki:3100`.

| Service | Image | Accès hôte | Rôle et stockage |
| :--- | :--- | :--- | :--- |
| **Application Node.js** | `node:24-alpine` | `http://localhost:8080` | Routes `/` et `/metrics`, écrit dans `monitoring-app_logs` |
| **Prometheus** | `prom/prometheus:v3.16.0` | `http://localhost:9090` | Collecte TSDB dans `monitoring-prometheus` (`/prometheus`) |
| **Grafana** | `grafana/grafana:13.3.0` | `http://localhost:3000` | Tableaux de bord et Explore dans `monitoring-grafana` |
| **Loki** | `grafana/loki:3.7.0` | `http://localhost:3100` | Stockage des journaux dans `monitoring-loki` (`/loki`) |
| **Grafana Alloy** | `grafana/alloy:v1.21.2` | Aucun port exposé | Collecteur de logs avec suivi de position (`monitoring-alloy`) |

### Déploiement et génération de trafic

```powershell
cd ..\supervision

tofu init
tofu fmt
tofu validate
tofu plan -out=monitoring.tfplan
tofu show monitoring.tfplan
tofu apply monitoring.tfplan

# Vérifier les 5 conteneurs
docker ps -a --filter name=monitoring-

# Générer des requêtes HTTP métier (200 et 404)
1..4 | ForEach-Object { curl.exe -s http://localhost:8080/ }
curl.exe -s http://localhost:8080/inexistant

# Contrôler les métriques, la disponibilité Loki et les journaux bruts
curl.exe -s http://localhost:8080/metrics
curl.exe -s http://localhost:3100/ready
docker exec monitoring-node tail -n 5 /logs/http.log
```

#### Vérifications dans Prometheus et Grafana :
1. **Prometheus (`http://localhost:9090/targets`) :** La cible `node` (`http://node:8080/metrics`) est à l'état **`UP`**.
2. **Sources Grafana (`http://localhost:3000`) :**
   * Data source **Prometheus** configurée sur `http://prometheus:9090` (`Save & test` validé).
   * Data source **Loki** configurée sur `http://loki:3100` (`Save & test` validé).
3. **Corrélation Métriques / Journaux dans Explore :**
   * Requêtes Prometheus : `up{job="node"}` (= `1`) et `http_requests_total` (affiche le nombre exact de requêtes métier reçues, hors scrapes `/metrics`).
   * Requête Loki : `{job="node"}` sur la même fenêtre temporelle, permettant de corréler chaque incrément du compteur `http_requests_total` avec les entrées JSON horodatées (`path`, `status`).

### Preuves de fonctionnement (Atelier 2)

```text
> curl.exe -s http://localhost:8080/metrics
# TYPE http_requests_total counter
http_requests_total 5
```
```text
> docker exec monitoring-node tail -n 5 /logs/http.log
{"time":"2026-11-19T12:53:33.365Z","path":"/","status":200}
{"time":"2026-11-19T12:53:33.597Z","path":"/","status":200}
{"time":"2026-11-19T12:53:33.813Z","path":"/","status":200}
{"time":"2026-11-19T12:53:34.046Z","path":"/","status":200}
{"time":"2026-11-19T12:53:34.294Z","path":"/inexistant","status":404}
```

### Nettoyage de l'environnement de supervision

```powershell
tofu plan -destroy -out=monitoring-destroy.tfplan
tofu show monitoring-destroy.tfplan
tofu apply monitoring-destroy.tfplan
docker ps -a --filter name=monitoring-
```

---

## 5. Bonnes pratiques appliquées

* **Exclusion des états et plans :** Les fichiers `*.tfstate`, `*.tfstate.*`, `*.tfplan` et le répertoire `.terraform/` sont ignorés via `.gitignore` afin de ne jamais exposer de données d'état ni de secrets dans Git.
* **Isolation réseau et exposition minimale :** Chaque environnement dispose de son propre réseau bridge Docker (`devops-net` / `monitoring-net`) et les ports publiés sont strictement limités à l'interface de bouclage `127.0.0.1`.