# Atelier A1 — MongoDB avec Docker

## Objectif

Déployer une instance MongoDB 7 via Docker Compose, exposée uniquement sur la boucle locale de l'hôte (`127.0.0.1`), insérer un document dans une base de données et vérifier la persistance des données grâce à un volume nommé (`mongo-data`) lors de la suppression et recréation du conteneur.

## Structure du dossier

```text
ateliers/a1-mongodb-docker/
├── README.md
└── mongo-local/
    └── compose.yaml
```

## Prérequis

* **Docker Desktop** démarré avec le moteur de conteneurs Linux actif.
* **Docker Compose** (plugin v2) disponible en ligne de commande.
* Port local `27017` disponible sur `127.0.0.1`.

Vérification des versions :
```bash
docker version
docker compose version
```

## Procédure d'exécution

### 1. Validation et démarrage du service

Se placer dans le répertoire contenant le fichier `compose.yaml`, valider sa syntaxe puis démarrer le conteneur en arrière-plan :

```bash
cd mongo-local
docker compose config --quiet
docker compose up -d
docker compose ps
```

### 2. Insertion et lecture d'un document dans MongoDB

Ouvrir un shell interactif `mongosh` dans le conteneur en s'authentifiant sur la base `admin` :

```bash
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin
```

Dans l'invite `mongosh`, sélectionner la base `support`, insérer le ticket `T-101` puis vérifier son enregistrement :

```javascript
use support

db.tickets.updateOne(
  { code: "T-101" },
  { $set: { sujet: "Acces au portail" } },
  { upsert: true }
)

db.tickets.findOne({ code: "T-101" })

exit
```

*(Note : depuis un client sur l'hôte, l'URI de connexion est `mongodb://root:example@127.0.0.1:27017/support?authSource=admin`. Depuis un autre conteneur du même projet Compose, il faut remplacer `127.0.0.1` par le nom du service `mongo`).*

### 3. Vérification de la persistance des données

Arrêter et supprimer le conteneur (ainsi que le réseau associé) sans supprimer les volumes, puis recréer un nouveau conteneur :

```bash
docker compose down
docker compose up -d
```

Se reconnecter à `mongosh` et vérifier que le document `T-101` est toujours présent :

```bash
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin
```

```javascript
use support
db.tickets.findOne({ code: "T-101" })
exit
```

## Résultats attendus et preuves de vérification

### État du conteneur (`docker compose ps`)

Le service `mongo` doit être actif (`Up` / `Running`) et lié au port `127.0.0.1:27017->27017/tcp` :

```text
NAME                  IMAGE     COMMAND                  SERVICE   CREATED          STATUS         PORTS
mongo-local-mongo-1   mongo:7   "docker-entrypoint.s…"   mongo     10 seconds ago   Up 9 seconds   127.0.0.1:27017->27017/tcp
```

### Persistance après redéploiement (`docker compose down` puis `up -d`)

Après destruction et recréation du conteneur, le volume nommé `mongo-data` conserve l'état de `/data/db`. La requête `findOne` retourne bien le document initialement inséré :

```text
{
  _id: ObjectId('6afd6e759de4bdeffbcde9e6'),
  code: 'T-101',
  sujet: 'Acces au portail'
}
```

## Nettoyage

* **Arrêter et supprimer le conteneur (en conservant les données dans le volume) :**
  ```bash
  docker compose down
  ```
* **Arrêter le conteneur et supprimer également le volume de données (remise à zéro complète) :**
  ```bash
  docker compose down -v
  ```