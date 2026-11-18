# Atelier B1 — Déployer Nginx avec OpenTofu

## Objectif

Déclarer une image Docker (`nginx:1.28-alpine`) et un conteneur web (`infra-si-nginx`) en langage HCL (*Infrastructure as Code*) avec OpenTofu, examiner le plan d'exécution, appliquer les changements, vérifier l'état de l'infrastructure ainsi que son idempotence, puis détruire proprement les ressources gérées.

## Structure du dossier

```text
ateliers/b1-nginx-opentofu/
├── .terraform.lock.hcl
├── main.tf
└── README.md
```

*(Les fichiers locaux sensibles ou générés tels que `.terraform/`, `*.tfstate*` et `*.tfplan` sont exclus du suivi Git via le `.gitignore` racine).*

## Prérequis

* **Système hôte :** Windows 10/11 avec PowerShell
* **Moteur de conteneurs :** Docker Desktop démarré en mode conteneurs Linux
* **Outil IaC :** OpenTofu (`tofu version`) installé et accessible dans le `PATH`
* **Encodage des fichiers :** Fichiers `.tf` enregistrés en **UTF-8 (sans BOM)**

## Procédure d'exécution

### 1. Initialiser le répertoire de travail et valider la configuration

Se placer dans `ateliers/b1-nginx-opentofu/` puis télécharger le provider `kreuzwerker/docker` (`~> 3.6`), formater et valider le fichier `main.tf` :

```powershell
tofu init
tofu fmt
tofu validate
```

### 2. Générer, inspecter et appliquer le plan d'exécution

*(Sous PowerShell, utiliser un espace entre `-out` et le nom du fichier `.tfplan`)* :

```powershell
tofu plan -out nginx.tfplan
tofu show nginx.tfplan
tofu apply nginx.tfplan
```

### 3. Vérifier le déploiement, l'état et l'idempotence

Contrôler l'URL exposée, l'état enregistré dans OpenTofu, l'accessibilité HTTP du conteneur Nginx et l'absence de dérive lors d'une nouvelle planification :

```powershell
tofu output nginx_url
tofu state list
docker ps --filter name=infra-si-nginx
curl.exe -I http://127.0.0.1:8080
tofu plan
```

## Résultats attendus et preuves de vérification

### Validation et plan d'exécution (`tofu validate` / `tofu plan`)

La configuration est valide et le plan initial prévoit l'ajout de 2 ressources (`docker_image.nginx` et `docker_container.nginx`) :

```text
> tofu validate
Success! The configuration is valid.
```
```text
> tofu plan -out nginx.tfplan

OpenTofu used the selected providers to generate the following execution plan. Resource actions are indicated with the
following symbols:
  + create

OpenTofu will perform the following actions:

  # docker_container.nginx will be created
  + resource "docker_container" "nginx" {
      + attach                                      = false
      + bridge                                      = (known after apply)
      + command                                     = (known after apply)
      + container_logs                              = (known after apply)
      + container_read_refresh_timeout_milliseconds = 15000
      + entrypoint                                  = (known after apply)
      + env                                         = (known after apply)
      + exit_code                                   = (known after apply)
      + hostname                                    = (known after apply)
      + id                                          = (known after apply)
      + image                                       = (known after apply)
      + init                                        = (known after apply)
      + ipc_mode                                    = (known after apply)
      + log_driver                                  = (known after apply)
      + logs                                        = false
      + memory_reservation                          = 0
      + must_run                                    = true
      + name                                        = "infra-si-nginx"
      + network_data                                = (known after apply)
      + network_mode                                = "bridge"
      + read_only                                   = false
      + remove_volumes                              = true
      + restart                                     = "no"
      + rm                                          = false
      + runtime                                     = (known after apply)
      + security_opts                               = (known after apply)
      + shm_size                                    = (known after apply)
      + start                                       = true
      + stdin_open                                  = false
      + stop_signal                                 = (known after apply)
      + stop_timeout                                = (known after apply)
      + tty                                         = false
      + wait                                        = false
      + wait_timeout                                = 60

      + healthcheck (known after apply)

      + labels (known after apply)

      + ports {
          + external = 8080
          + internal = 80
          + ip       = "127.0.0.1"
          + protocol = "tcp"
        }
    }

  # docker_image.nginx will be created
  + resource "docker_image" "nginx" {
      + id           = (known after apply)
      + image_id     = (known after apply)
      + keep_locally = true
      + name         = "nginx:1.28-alpine"
      + repo_digest  = (known after apply)
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + nginx_url = "http://127.0.0.1:8080"

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: nginx.tfplan

To perform exactly these actions, run the following command to apply:
    tofu apply "nginx.tfplan"
```

### État OpenTofu et accès web (`tofu state list`, `tofu output` et `curl.exe`)

Le conteneur `infra-si-nginx` est actif sur le port `127.0.0.1:8080` et répond `HTTP/1.1 200 OK` :

```text
tofu state list
docker_container.nginx
docker_image.nginx
```
```text
> tofu output nginx_url
"http://127.0.0.1:8080"
```
```text
> curl.exe -I http://127.0.0.1:8080
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Wed, 18 Nov 2026 15:09:28 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 24 Mar 2026 19:45:11 GMT
Connection: keep-alive
ETag: "69c2e9c7-267"
Accept-Ranges: bytes
```

### Vérification de l'idempotence (`tofu plan` après `apply`)

Aucune modification n'est proposée lorsque l'infrastructure réelle correspond à la déclaration :

```text
> tofu plan
docker_image.nginx: Refreshing state... [id=sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236nginx:1.28-alpine]
docker_container.nginx: Refreshing state... [id=6deaad04c8976ac1bc221c10f5e57c28198dcf2504a6e0c10d964e086bb7cc31]

No changes. Your infrastructure matches the configuration.
```

## Nettoyage

Planifier et appliquer la destruction des ressources gérées par OpenTofu, puis supprimer les fichiers de plan locaux :

```powershell
tofu plan -destroy -out nginx-destroy.tfplan
tofu show nginx-destroy.tfplan
tofu apply nginx-destroy.tfplan
docker ps -a --filter name=infra-si-nginx
Remove-Item *.tfplan
```