# Atelier A3 — Connecter une VM (Réseau privé hôte et IP statique)

## Objectif

Ajouter une seconde interface réseau (**Réseau privé hôte** / *Host-Only*) à la machine virtuelle `UbuntuDev` et lui attribuer une adresse IP statique (`192.168.56.20/24`) via Netplan. L'objectif est de permettre une communication directe (ping, SSH et HTTP) depuis le poste hôte Windows sans redirection de port, tout en conservant l'accès à Internet via la première interface NAT.

## Structure du dossier

```text
ateliers/a3-reseau-vm/
└── README.md
```

## Architecture réseau et paramètres

* **Hyperviseur :** Oracle VirtualBox
* **VM cible :** `UbuntuDev` (Ubuntu Server 24.04 LTS)
* **Configuration des cartes réseau :**
  * **Adaptateur 1 (`enp0s3`) :** NAT — Configuration automatique via DHCP (ex. `10.0.2.15/24`, passerelle `10.0.2.2`) pour l'accès sortant vers Internet.
  * **Adaptateur 2 (`enp0s8`) :** Réseau privé hôte (*Host-Only Adapter*) sur le sous-réseau `192.168.56.0/24` (interface hôte Windows `192.168.56.1`), configuré en IP statique `192.168.56.20/24` sans passerelle par défaut.

## Prérequis

* **Réutilisation de la VM de l'atelier A2 :** Cet atelier réutilise directement la machine virtuelle `UbuntuDev` (Ubuntu Server 24.04 LTS avec OpenSSH Server) préparée lors de l'atelier `a2-vm-linux-conteneur-web`. Avant toute modification matérielle, éteindre proprement la VM avec `sudo poweroff`.
* **Hyperviseur :** Oracle VirtualBox 7.x avec un réseau privé hôte (*Host-Only Network*) actif sur la plage `192.168.56.0/24` (passerelle hôte `192.168.56.1`).
* **Interfaces réseau configurées sur `UbuntuDev` :**
  * **Adaptateur 1 :** NAT (conservé pour l'accès Internet et la résolution DNS).
  * **Adaptateur 2 :** Réseau privé hôte (*Host-Only Adapter*) pour la communication directe avec l'hôte sur `192.168.56.20/24`.
* **Outils sur le poste hôte (Windows) :** Terminal PowerShell ou client SSH (`ssh`, `ping`, `curl.exe`).

## Procédure d'exécution

### 1. Ajout de l'interface réseau dans VirtualBox

1. Arrêt propre de la VM (`sudo poweroff`).
2. Vérification dans **Fichier > Outils > Gestionnaire de réseau** que le réseau privé hôte `192.168.56.0/24` est actif.
3. Activation de l'**Adaptateur 2** en mode **Réseau privé hôte** dans la configuration réseau de `UbuntuDev`, puis redémarrage de la VM.

### 2. Configuration Netplan dans la VM

Création du fichier `/etc/netplan/60-lab.yaml` dédié uniquement à la seconde interface (`enp0s8`) afin de ne pas interférer avec le fichier Netplan initial de `enp0s3` :

```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.56.20/24
```

Application des permissions restrictives, génération et validation de la configuration :

```bash
sudo chmod 600 /etc/netplan/60-lab.yaml
sudo netplan generate
sudo netplan try
```

### 3. Tests de connectivité

* **Depuis la VM (`UbuntuDev`) :**
  ```bash
  ip -br addr
  ip route
  getent hosts ubuntu.com
  ```
* **Depuis le poste hôte (Windows PowerShell) :**
  ```powershell
  ping 192.168.56.20
  ssh user@192.168.56.20
  curl.exe -I http://192.168.56.20:8088
  ```

## Résultats attendus et preuves de vérification

### Interfaces et table de routage (`ip -br addr` et `ip route`)

Les deux interfaces sont à l'état `UP` : `enp0s3` conserve son adresse DHCP NAT ainsi que la unique route `default`, tandis que `enp0s8` porte l'adresse statique `192.168.56.20/24` :

```text
$ ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp0s3           UP             10.0.2.15/24 metric 100 fd17:625c:f037:2:a00:27ff:fe3f:3681/64 fe80::a00:27ff:fe3f:3681/64
enp0s8           UP             192.168.56.20/24 fe80::a00:27ff:fefe:8cde/64
docker0          DOWN           172.17.0.1/16
```
```text
$ ip route
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
10.0.2.2 dev enp0s3 proto dhcp scope link src 10.0.2.15 metric 100
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.1.1 via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
192.168.56.0/24 dev enp0s8 proto kernel scope link src 192.168.56.20
```

### Résolution DNS et accès Internet (`getent hosts ubuntu.com`)

La résolution de noms fonctionne toujours via l'interface NAT :

```text
$ getent hosts ubuntu.com
2620:2d:4000:1::26 ubuntu.com
2620:2d:4000:1::28 ubuntu.com
2620:2d:4000:1::27 ubuntu.com
```

### Accessibilité directe depuis Windows (ICMP, SSH et HTTP)

La VM répond directement sur `192.168.56.20` sans redirection de port :

```text
> ping 192.168.56.20

Envoi d’une requête 'Ping'  192.168.56.20 avec 32 octets de données :
Réponse de 192.168.56.20 : octets=32 temps=89 ms TTL=64
Réponse de 192.168.56.20 : octets=32 temps<1ms TTL=64
Réponse de 192.168.56.20 : octets=32 temps=1 ms TTL=64
Réponse de 192.168.56.20 : octets=32 temps=1 ms TTL=64

Statistiques Ping pour 192.168.56.20:
    Paquets : envoyés = 4, reçus = 4, perdus = 0 (perte 0%),
Durée approximative des boucles en millisecondes :
    Minimum = 0ms, Maximum = 89ms, Moyenne = 22ms
```
```text
> curl.exe -I http://192.168.56.20:8088
HTTP/1.1 200 OK
Server: nginx/1.28.3
Date: Wed, 18 Nov 2026 13:11:11 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Tue, 24 Mar 2026 19:45:11 GMT
Connection: keep-alive
ETag: "69c2e9c7-267"
Accept-Ranges: bytes
```