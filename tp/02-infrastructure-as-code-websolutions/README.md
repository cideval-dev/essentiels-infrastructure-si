# TP 02 — Infrastructure as Code : WebSolutions Inc.

## 1. Objectif et architecture

Mettre en œuvre une chaîne de livraison reproductible de bout en bout pour **WebSolutions Inc.** en séparant clairement trois responsabilités :

1. **Provisionnement (`infra/`)** : Déclaration avec **OpenTofu** d'un réseau Docker isolé (`websolutions-net`), d'un volume persistant (`websolutions-pgdata`), d'une base **PostgreSQL** (`websolutions-db`), d'une API **Node.js** (`websolutions-api`) et d'un reverse-proxy **Nginx** (`websolutions-web`, exposé uniquement sur `127.0.0.1:8080`).
2. **Configuration et maintien (`config/`)** :
   * **Ansible (`config/ansible/`)** : Amorçage de `python3` sur Alpine, installation de `curl`, déploiement du template Jinja2 reverse-proxy `/etc/nginx/conf.d/default.conf` (`0644`, `root:root`) et rechargement à chaud d'Nginx.
   * **Puppet (`config/puppet/`)** : Manifeste déclaratif `site.pp` gérant les paquets (`nginx`, `curl`), le fichier de configuration `/etc/nginx/conf.d/default.conf` et le maintien du service `nginx` (`nginx -s reload`).
3. **Livraison continue (`pipeline/deploy.ps1`)** : Automatisation du build d'artefact Docker étiqueté, de l'exécution des tests unitaires bloquants, du déploiement via OpenTofu, du contrôle HTTP sur `/health` et du rollback vers une version précédente.

### Arborescence du projet

```text
tp/02-infrastructure-as-code-websolutions/
├── app/
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   └── test.js
├── config/
│   ├── ansible/
│   │   ├── Dockerfile
│   │   ├── inventory.ini
│   │   ├── nginx-reverse-proxy.conf.j2
│   │   └── playbook.yml
│   └── puppet/
│       └── manifests/
│           └── site.pp
├── infra/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
├── pipeline/
│   └── deploy.ps1
└── README.md
```

---

## 2. Prérequis

* **Système hôte :** Windows 10/11 avec PowerShell 5.1+ ou PowerShell 7+
* **Moteur de conteneurs :** Docker Desktop en mode conteneurs Linux
* **Provisionnement :** OpenTofu (`tofu`) installé dans le `PATH`

---

## 3. Procédure de démarrage et d'exécution

### Étape 1 — Construire et tester l'application (`app/`)

```powershell
cd tp\02-infrastructure-as-code-websolutions\app
docker build -t websolutions-api:1.0.0 .
docker run --rm websolutions-api:1.0.0 npm test
```

### Étape 2 — Provisionner l'infrastructure avec OpenTofu (`infra/`)

Le mot de passe de la base de données est injecté via variable d'environnement (`TF_VAR_db_password`) afin de ne stocker aucun secret dans le dépôt Git :

```powershell
cd ..\infra
$env:TF_VAR_db_password = "WsLocalSecret2026!"

tofu init
tofu fmt -check
tofu validate
tofu plan -out infra.tfplan
tofu show infra.tfplan
tofu apply infra.tfplan
tofu output

# Vérification de la stabilité de l'état (0 changement attendu)
tofu plan
```

### Étape 3A — Configurer et maintenir avec Ansible (`config/ansible/`)

```powershell
cd ..\config\ansible

# Construire l'image Ansible embarquant le SDK Python Docker (requests / docker)
docker build -t websolutions-ansible:1.0 .

# 1. Première application : amorce Python3, installe curl, déploie la config et recharge Nginx
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/ansible" -w /ansible websolutions-ansible:1.0 ansible-playbook -i inventory.ini playbook.yml

# Contrôle HTTP bout-en-bout (Hôte -> Nginx:8080 -> API:3000 -> PostgreSQL)
curl.exe -i http://127.0.0.1:8080/health

# 2. Seconde application : preuve d'idempotence (attendu : ok=4 changed=0 failed=0)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/ansible" -w /ansible websolutions-ansible:1.0 ansible-playbook -i inventory.ini playbook.yml

# 3. Dérive manuelle puis remédiation automatique
docker exec websolutions-web sh -c "echo '# derive test' >> /etc/nginx/conf.d/default.conf"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/ansible" -w /ansible websolutions-ansible:1.0 ansible-playbook -i inventory.ini playbook.yml
```

### Étape 3B — Configurer et maintenir avec Puppet (`config/puppet/`)

```powershell
cd ..\puppet

# Démarrer une cible Ubuntu reliée au réseau websolutions-net sur le port 8081
docker run -d --name websolutions-puppet-target --network websolutions-net -p 127.0.0.1:8081:80 -v "${PWD}/manifests:/manifests" --entrypoint sleep puppet/puppet-agent-ubuntu infinity

# 1. Première application : apt-update, installation nginx/curl, config, démarrage service
docker exec websolutions-puppet-target puppet apply /manifests/site.pp
curl.exe -i http://127.0.0.1:8081/health

# 2. Seconde application : preuve d'idempotence (0 ressource modifiée)
docker exec websolutions-puppet-target puppet apply /manifests/site.pp

# 3. Dérive manuelle puis remédiation automatique
docker exec websolutions-puppet-target bash -c "echo '# derive test' >> /etc/nginx/conf.d/default.conf"
docker exec websolutions-puppet-target puppet apply /manifests/site.pp

# Suppression du conteneur de démonstration Puppet
docker rm -f websolutions-puppet-target
```

### Étape 4 — Pipeline CI/CD local, test bloquant et rollback (`pipeline/`)

```powershell
cd ..\..\pipeline

# 1. Test bloquant : altérer temporairement test.js et vérifier que le déploiement est bloqué
(Get-Content ..\app\test.js) -replace "'ok'", "'fail_expected'" | Set-Content ..\app\test.js
.\deploy.ps1 -Version "1.1.0-broken"

# 2. Rétablir le test et livrer la version 1.1.0
(Get-Content ..\app\test.js) -replace "'fail_expected'", "'ok'" | Set-Content ..\app\test.js
.\deploy.ps1 -Version "1.1.0"
curl.exe -i http://127.0.0.1:8080/health

# 3. Rollback vers la version précédente (1.0.0)
.\deploy.ps1 -Version "1.0.0"
curl.exe -i http://127.0.0.1:8080/health
```

---

## 4. Preuves de validation

### Provisionnement OpenTofu (`tofu output` et second `tofu plan`)

```text
> tofu output
db_volume = "websolutions-pgdata"
network_name = "websolutions-net"
web_url = "http://127.0.0.1:8080"
```
```text
> tofu plan
docker_volume.pgdata: Refreshing state... [id=websolutions-pgdata]
docker_image.nginx: Refreshing state... [id=sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236nginx:1.28-alpine]
docker_network.websolutions_net: Refreshing state... [id=29563a4d2d671e2144355cccc858e5844e876a27051136f1bcb063bb717d99a3]
docker_image.postgres: Refreshing state... [id=sha256:526f86d93c6ea08fd3f1fe5605650cacc781b2c6013169a0ad8f42c7d3d84f32postgres:17-alpine]
docker_container.db: Refreshing state... [id=8532a1947893ad518f63a2b7144aa50865b23245bd2d0e1f889d1e8660306916]
docker_container.api: Refreshing state... [id=c70214939ded8befc03f8ca4edd37a89e922278eaa2b47ff65d552af1399d29e]
docker_container.web: Refreshing state... [id=13e0522bf849cf6a2c51b2c8a519577861d16fde7e8a3f7413a072056113ee84]

No changes. Your infrastructure matches the configuration.
```

### Configuration Ansible (idempotence et remédiation de dérive)

* **2e exécution (idempotence) :** `websolutions-web : ok=4 changed=0 unreachable=0 failed=0`
* **Après altération manuelle de `/etc/nginx/conf.d/default.conf` :** `websolutions-web : ok=5 changed=2 unreachable=0 failed=0` (restauration du fichier et déclenchement du handler `Recharger Nginx`)
* **Réponse HTTP (`GET http://127.0.0.1:8080/health`) :**
  ```json
  {"status":"ok","version":"1.0.0","dbHost":"websolutions-db"}
  ```

### Configuration Puppet (idempotence et remédiation de dérive)

Tester l'acces HTTP bout en bout (Hote -> Nginx:8080 -> API:3000)
```text
> curl.exe -i http://127.0.0.1:8080/health
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Thu, 19 Nov 2026 10:49:30 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"ok","version":"1.0.0","dbHost":"websolutions-db"}
```
Execution d'idempotence (attendu : ok=4 changed=0 failed=0)
```text
> docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/ansible" -w /ansible websolutions-ansible:1.0 ansible-playbook -i inventory.ini playbook.yml
PLAY RECAP *********************************************************************
websolutions-web           : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Derive manuelle puis remediation (attendu : ok=4 changed=2 failed=0)
```text
> docker exec websolutions-web sh -c "echo '# derive test' >> /etc/nginx/conf.d/default.conf"

> docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/ansible" -w /ansible websolutions-ansible:1.0 ansible-playbook -i inventory.ini playbook.yml
[INFO] root> ansible-playbook -i inventory.ini playbook.yml

PLAY [Configurer et maintenir le reverse-proxy Nginx de WebSolutions] **********

RUNNING HANDLER [Recharger Nginx] **********************************************
changed: [websolutions-web]

PLAY RECAP *********************************************************************
websolutions-web           : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Pipeline CI/CD et rollback

```text
> (Get-Content ..\app\test.js) -replace "'ok'", "'fail_expected'" | Set-Content ..\app\test.js

> .\deploy.ps1 -Version "1.1.0-broken"
=== [1/4] Construction de l'artefact websolutions-api:1.1.0-broken ===
[+] Building 1.8s (9/9) FINISHED                                                                          
=== [2/4] Execution des tests automatises sur websolutions-api:1.1.0-broken ===

> websolutions-api@1.0.0 test
> node test.js

Tests failed:  Expected values to be strictly equal:
+ actual - expected

+ 'ok'
- 'fail_expected'


BLOCAGE PIPELINE : Les tests ont echoue. Aucun deploiement effectue.

> curl.exe -s http://127.0.0.1:8080/health
{"status":"ok","version":"1.0.0","dbHost":"websolutions-db"}
```
```text
> (Get-Content ..\app\test.js) -replace "'fail_expected'", "'ok'" | Set-Content ..\app\test.js

> .\deploy.ps1 -Version "1.1.0"
=== [1/4] Construction de l'artefact websolutions-api:1.1.0 ===
[+] Building 1.2s (8/8) FINISHED                                                                          
=== [2/4] Execution des tests automatises sur websolutions-api:1.1.0 ===

> websolutions-api@1.0.0 test
> node test.js

Tests OK:  { status: 'ok', version: '1.0.0', dbHost: 'localhost' }
=== [3/4] Deploiement sur la cible de test via OpenTofu (version 1.1.0) ===

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

Outputs:

db_volume = "websolutions-pgdata"
network_name = "websolutions-net"
web_url = "http://127.0.0.1:8080"
2026/11/19 12:09:20 [notice] 641#641: signal process started
=== [4/4] Controle HTTP de sante (/health) ===
SUCCES : Version 1.1.0 deployee et validee ({"status":"ok","version":"1.1.0","dbHost":"websolutions-db"})
> curl.exe -i http://127.0.0.1:8080/health
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Thu, 19 Nov 2026 12:09:31 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"ok","version":"1.1.0","dbHost":"websolutions-db"}

> .\deploy.ps1 -Version "1.0.0"
=== [1/4] Construction de l'artefact websolutions-api:1.0.0 ===
[+] Building 0.9s (8/8) FINISHED                                                                          
=== [2/4] Execution des tests automatises sur websolutions-api:1.0.0 ===

> websolutions-api@1.0.0 test
> node test.js

Tests OK:  { status: 'ok', version: '1.0.0', dbHost: 'localhost' }
=== [3/4] Deploiement sur la cible de test via OpenTofu (version 1.0.0) ===

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

Outputs:

db_volume = "websolutions-pgdata"
network_name = "websolutions-net"
web_url = "http://127.0.0.1:8080"
2026/11/19 12:10:00 [notice] 663#663: signal process started
=== [4/4] Controle HTTP de sante (/health) ===
SUCCES : Version 1.0.0 deployee et validee ({"status":"ok","version":"1.0.0","dbHost":"websolutions-db"})
> curl.exe -i http://127.0.0.1:8080/health
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Thu, 19 Nov 2026 12:10:02 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"ok","version":"1.0.0","dbHost":"websolutions-db"}
```

---

## 5. Analyse : difficultés, décisions et passage en production

### Décisions techniques et difficultés rencontrées

* **Séparation des responsabilités :** OpenTofu gère exclusivement le cycle de vie des conteneurs, réseaux et volumes ; Ansible et Puppet gèrent la configuration interne des services (`nginx.conf`, paquets, droits).
* **Environnement Docker minimaliste (Alpine / Ubuntu) :**
  * L'image cible `nginx:1.28-alpine` ne contient pas Python : ajout d'une tâche préliminaire idempotente `ansible.builtin.raw` pour amorcer `python3`, et construction d'une image de contrôle `websolutions-ansible:1.0` embarquant `requests` et `docker` pour dialoguer via `community.docker.docker_api`.
  * L'image `puppet/puppet-agent-ubuntu` repose sur Ubuntu `bionic` avec un dépôt `apt.puppetlabs.com` expiré : nettoyage de `/etc/apt/sources.list.d/puppet*.list` avant `apt-get update` et utilisation de `nginx -s reload` pour le redémarrage sans coupure.
* **Immutabilité des artefacts :** Chaque version applicative est construite une fois et étiquetée (`websolutions-api:1.0.0`, `websolutions-api:1.1.0`), rendant le rollback quasi instantané sans recompiler.

### Limites du scénario local et adaptations pour la production

| Dimension | Scénario local (TP) | Cible Production (WebSolutions Inc.) |
| :--- | :--- | :--- |
| **Hébergement & Haute Disponibilité** | Conteneurs Docker sur un seul poste hôte (point de défaillance unique). | Cluster orchestré multi-nœuds (Kubernetes / ECS) ou VMs réparties sur plusieurs zones de disponibilité avec auto-scaling. |
| **État OpenTofu (`tfstate`)** | Fichier local `terraform.tfstate` exclu du dépôt Git. | Backend distant chiffré avec verrouillage d'état (S3 + DynamoDB ou stockage objet compatible) pour le travail collaboratif. |
| **Gestion des secrets** | Variable d'environnement locale `$env:TF_VAR_db_password`. | Coffre-fort dédié (HashiCorp Vault, AWS Secrets Manager) avec rotation automatique des identifiants. |
| **Sécurité réseau & TLS** | Trafic HTTP en clair sur `127.0.0.1:8080`. | Terminaison TLS/HTTPS (certificats automatisés), pare-feu/Security Groups stricts et segmentation réseau (DMZ / App / DB). |
| **Persistance & Sauvegardes** | Volume Docker local `websolutions-pgdata` sans sauvegarde automatisée. | Base de données managée (RDS / Cloud SQL) avec sauvegardes automatiques, réplication et plan de reprise d'activité (PRA). |
| **Pipeline CI/CD** | Script PowerShell local déclenché manuellement. | Pipeline hébergé (GitHub Actions / GitLab CI) déclenché sur Pull Request, registre d'images privé signé et déploiement *Blue/Green* ou *Canary*. |

---

## 6. Arrêt et nettoyage propre

Avant de détruire l'environnement de test, vérifier les données persistantes (sauvegarde SQL éventuelle), prévisualiser le plan de destruction puis supprimer uniquement les ressources du laboratoire :

```powershell
# (Optionnel) Sauvegarder la base PostgreSQL avant destruction
docker exec websolutions-db pg_dump -U ws_user websolutions > backup_websolutions.sql

# Prévisualiser et exécuter la destruction ciblée via OpenTofu
cd tp\02-infrastructure-as-code-websolutions\infra
tofu plan -destroy
tofu destroy -auto-approve
```