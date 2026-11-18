# Atelier A4 — Attacher et monter un disque virtuel

## Objectif

Attacher un second disque dur virtuel VDI à la machine virtuelle `UbuntuDev`, créer une table de partition GPT et un système de fichiers `ext4`, monter le volume sur `/mnt/lab-data`, vérifier la persistance d'un fichier témoin lors d'un démontage/remontage manuel, puis rendre ce montage permanent au démarrage via `/etc/fstab` à l'aide de son identifiant unique (`UUID`).

## Structure du dossier

```text
ateliers/a4-stockage-virtuel/
└── README.md
```

## Paramètres de stockage

* **Hyperviseur :** Oracle VirtualBox
* **VM cible :** `UbuntuDev` (Ubuntu Server 24.04 LTS)
* **Nouveau disque virtuel :**
  * **Format :** VDI (*VirtualBox Disk Image*)
  * **Allocation :** Dynamique
  * **Capacité :** 2 Go
  * **Périphérique détecté :** `/dev/sdb` (partition unique `/dev/sdb1`)
  * **Table de partition :** GPT
  * **Système de fichiers :** `ext4`
  * **Point de montage :** `/mnt/lab-data`

## Prérequis

* **Réutilisation de la VM de l'atelier A2 :** Cet atelier réutilise la machine virtuelle `UbuntuDev` (Ubuntu Server 24.04 LTS) créée lors de l'atelier `a2-vm-linux-conteneur-web` (et connectée en réseau dans `a3-reseau-vm`). Éteindre la VM avec `sudo poweroff` avant d'attacher le nouveau disque virtuel.
* **Hyperviseur :** Oracle VirtualBox 7.x.
* **Stockage virtuel ajouté :** Un second disque dur virtuel au format **VDI** (allocation dynamique) de **2 Go** attaché au contrôleur SATA de la VM `UbuntuDev` (détecté en tant que `/dev/sdb`).
* **Outils système dans la VM :** Utilitaires standard Ubuntu (`lsblk`, `fdisk`, `mkfs.ext4`, `blkid`, `findmnt`).

## Procédure d'exécution

### 1. Création et attachement du disque dans VirtualBox

1. Arrêt propre de la VM (`sudo poweroff`).
2. Dans **Configuration > Stockage**, ajout d'un second disque dur VDI dynamique de 2 Go sur le contrôleur SATA de `UbuntuDev`, puis redémarrage.

### 2. Repérage, partitionnement et formatage

Repérage du périphérique bloc vierge de 2 Go :

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

Création de la table GPT (`g`), d'une partition principale (`n`) et écriture (`w`) avec `fdisk`, suivies du formatage en `ext4` :

```bash
sudo fdisk /dev/sdb
sudo mkfs.ext4 /dev/sdb1
```

### 3. Montage manuel et test du fichier témoin

Création du répertoire de montage, montage de `/dev/sdb1`, écriture du fichier témoin et test de démontage/remontage :

```bash
sudo mkdir -p /mnt/lab-data
sudo mount /dev/sdb1 /mnt/lab-data
echo "Disque de test" | sudo tee /mnt/lab-data/temoin.txt
findmnt /mnt/lab-data

sudo umount /mnt/lab-data
sudo mount /dev/sdb1 /mnt/lab-data
cat /mnt/lab-data/temoin.txt
```

### 4. Montage permanent via `/etc/fstab`

Récupération de l'`UUID` unique de la partition :

```bash
sudo blkid /dev/sdb1
```

Ajout de l'entrée correspondante dans `/etc/fstab` :

```text
UUID=<UUID_DE_SDB1>  /mnt/lab-data  ext4  defaults  0  2
```

Validation de la syntaxe avant redémarrage, puis vérification après redémarrage complet (`sudo reboot`) :

```bash
sudo umount /mnt/lab-data
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/lab-data
```

## Résultats attendus et preuves de vérification

### Arborescence des disques et partitions (`lsblk`)

Le disque `sdb` de 2G contient la partition `sdb1` formatée en `ext4` et montée sur `/mnt/lab-data` :

```text
$ lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
NAME                       SIZE TYPE FSTYPE      MOUNTPOINTS
sda                         20G disk
├─sda1                       1M part
├─sda2                     1,8G part ext4        /boot
└─sda3                    18,2G part LVM2_member
  └─ubuntu--vg-ubuntu--lv   10G lvm  ext4        /
sdb                          2G disk
└─sdb1                       2G part ext4
sr0                       1024M rom
```

### Identifiant unique et configuration `/etc/fstab` (`blkid` et `/etc/fstab`)

L'entrée utilise l'`UUID` pour garantir la stabilité du montage indépendamment de l'ordre de détection des périphériques :

```text
$ sudo blkid /dev/sdb1
/dev/sdb1: UUID="1efc9d9a-1061-4f33-aba1-e3d54b4b6565" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="1d6b0892-8adc-49ea-958a-711c79af4dfe"
```
Ajout de cette ligne avec la commande ```sudo nano /etc/fstab``` :
```text
UUID=1efc9d9a-1061-4f33-aba1-e3d54b4b6565  /mnt/lab-data  ext4  defaults  0  2
```

### Persistance après redémarrage (`findmnt` et `temoin.txt`)

Après redémarrage complet de la VM (`sudo reboot`), le volume est automatiquement monté et le fichier témoin est intact :

```text
TARGET        SOURCE    FSTYPE OPTIONS
/mnt/lab-data /dev/sdb1 ext4   rw,relatime
Disque de test
```