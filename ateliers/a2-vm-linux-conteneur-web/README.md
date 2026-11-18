# Atelier A2 — VM Linux conteneur web

## Objectif

Créer une machine virtuelle sous Ubuntu Server 24.04 LTS (`UbuntuDev`), identifier sa configuration réseau initiale (NAT), installer Docker Engine et déployer un conteneur Nginx accessible depuis l'intérieur de la VM ainsi que depuis l'hôte Windows via une redirection de port.

## Structure du dossier

```text
ateliers/a2-vm-linux-conteneur-web/
└── README.md
```

## Prérequis et paramètres de la VM

* **Hyperviseur :** Oracle VirtualBox
* **Image ISO :** Ubuntu Server 24.04 LTS
* **Configuration matérielle de la VM (`UbuntuDev`) :**
  * **Processeurs :** 2 vCPU
  * **Mémoire vive :** 2 Go (2048 Mo)
  * **Disque virtuel :** VDI (VirtualBox Disk Image) dynamique de 20 Go
  * **Réseau (Adaptateur 1) :** NAT (avec OpenSSH Server installé)
* **Redirection de port NAT (VirtualBox) :**
  * **Protocole :** TCP
  * **IP / Port hôte :** `127.0.0.1:8088`
  * **IP / Port invité :** `8088`

## Procédure d'exécution

### 1. Inspection réseau initiale dans la VM

Après démarrage et connexion sur `UbuntuDev`, relever les interfaces réseau et la table de routage :

```bash
ip -br addr
ip route
```

### 2. Installation de Docker Engine et démarrage de Nginx

Installer Docker Engine depuis les dépôts officiels Ubuntu, puis lancer le conteneur `web-vm` en publiant le port `80` du conteneur sur le port `8088` de la VM :

```bash
docker run -d --name web-vm -p 8088:80 nginx:1.28-alpine
docker ps
docker exec web-vm nginx -t
```

### 3. Tests d'accès HTTP

* **Depuis la VM (`UbuntuDev`) :**
  ```bash
  curl -I http://127.0.0.1:8088
  ```
* **Depuis le poste hôte (Windows) :**
  Ouvrir `http://127.0.0.1:8088` dans un navigateur web ou exécuter `curl.exe -I http://127.0.0.1:8088` dans PowerShell.

## Résultats attendus et preuves de vérification

### Interfaces et route par défaut (`ip -br addr` et `ip route`)

L'interface NAT (`enp0s3`) obtient une adresse IPv4 privée (ex. `10.0.2.15/24`) et une route par défaut via la passerelle VirtualBox (`10.0.2.2`) :

```text
$ ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp0s3           UP             10.0.2.15/24 metric 100 fd17:625c:f037:2:a00:27ff:fe3f:3681/64 fe80::a00:27ff:fe3f:3681/64
docker0          UP             172.17.0.1/16 fe80::50a1:74ff:fe76:3dc6/64
veth4bc587b@if2  UP             fe80::a89f:d0ff:fee3:4016/64
```
```text
$ ip route
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
10.0.2.2 dev enp0s3 proto dhcp scope link src 10.0.2.15 metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
192.168.1.1 via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
```

### Conteneur Nginx actif (`docker ps` et `nginx -t`)

Le conteneur `web-vm` est en cours d'exécution et sa configuration Nginx est valide :

```text
$ docker ps
CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS          PORTS                                     NAMES
ddfd4f05fff6   nginx:1.28-alpine   "/docker-entrypoint.…"   21 minutes ago   Up 21 minutes   0.0.0.0:8088->80/tcp, [::]:8088->80/tcp   web-vm
```
```text
$ docker exec web-vm nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Accès HTTP depuis la VM et l'hôte

Les deux requêtes vers `http://127.0.0.1:8088` retournent un code `HTTP/1.1 200 OK` et la page d'accueil par défaut de Nginx (*Welcome to nginx!*) :

```text
$ curl -I http://127.0.0.1:8088
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Wed, 18 Nov 2026 12:49:00 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 24 Mar 2026 19:45:11 GMT
Connection: keep-alive
ETag: "69c2e9c7-267"
Accept-Ranges: bytes
```

## Nettoyage

Pour supprimer le conteneur Nginx :

```bash
docker rm -f web-vm
```