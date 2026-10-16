# Fiche mémo Nix — analyser le store et son impact disque

L'objectif est de comprendre où part l'espace disque dans `/nix/store`, quels paquets occupent le plus de place, quelles dépendances retiennent des fichiers et ce qu'il est possible de nettoyer sans casser ton environnement NixOS.

## 1. Mesurer l'espace disque

Diagnostic rapide — commence toujours par là.

| Commande                                                   | Utilité                                           |
| ---------------------------------------------------------- | ------------------------------------------------- |
| `df -h /nix`                                               | Espace libre et utilisé sur la partition du store |
| `du -sh /nix/store`                                        | Taille totale apparente du store                  |
| `du -sh /nix/store/* 2>/dev/null \\| sort -h \\| tail -20` | Les 20 répertoires les plus volumineux            |
| `nix store info`                                           | Informations sur le store Nix                     |
| `nix path-info --all --size`                               | Taille de tous les chemins connus du store        |
| `nix store verify --all`                                   | Vérifier l'intégrité des chemins du store         |

Attention : la taille apparente de `/nix/store` n'est pas forcément égale à l'espace disque réellement consommé. Les liens physiques (hard links), les fichiers partagés et les systèmes de fichiers en lecture seule peuvent modifier le résultat.

## 2. Identifier les paquets qui prennent le plus de place

### Classer les chemins du store par taille

```
nix path-info --all --size \
  | sort -k2,2n \
  | tail -30
```

Affiche les chemins connus du store avec leur taille, puis conserve les 30 plus gros.

Pour obtenir une sortie plus lisible :

```
nix path-info --all --size \
  | sort -k2,2n \
  | tail -30 \
  | numfmt --field=2 --to=iec
```

### Examiner un paquet précis

```
nix path-info nixpkgs#firefox --size
```

Pour afficher sa taille et celle de ses dépendances :

```
nix path-info --recursive --size nixpkgs#firefox
```

Le mode récursif inclut les chemins référencés dans la fermeture (closure). Attention : additionner leurs tailles peut compter plusieurs fois des dépendances partagées entre paquets.

## 3. Comprendre les dépendances et les closures

C'est particulièrement important avec Nix : un paquet ne peut pas toujours être supprimé parce qu'il semble inutilisé. D'autres chemins du store peuvent en dépendre.

### Commandes essentielles

Afficher les dépendances directes

```
nix-store --query --references /nix/store/…-mon-paquet
```

Afficher la closure complète

```
nix-store --query --requisites /nix/store/…-mon-paquet
```

Trouver les chemins qui dépendent d'un paquet

```
nix-store --query --referrers /nix/store/…-mon-paquet
```

Trouver pourquoi un paquet dépend d'un autre

```
nix why-depends \
  /run/current-system \
  /nix/store/…-openssl-…
```

Remplace les chemins d'exemple par des chemins réels. `nix why-depends` est particulièrement utile pour comprendre pourquoi une bibliothèque reste présente dans une closure.

## 4. Identifier ce qui empêche la suppression

Nix protège les chemins encore référencés par des garbage collection roots : générations système, profils, liens ou autres références actives.

```
# Lister les racines connues du store
nix-store --gc --print-roots
```

Pour examiner les générations système NixOS :

```
sudo nix-env --list-generations \
  --profile /nix/var/nix/profiles/system
```

Pour les générations de ton profil utilisateur :

```
nix-env --list-generations
```

Pour vérifier pourquoi un paquet reste nécessaire, combine les commandes précédentes avec `nix-store --query --referrers`.

## 5. Nettoyer sans supprimer à l'aveugle

Commence par simuler les opérations avant de lancer un nettoyage réel.

| Commande                                      | Effet                                                                                       |
| --------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `nix-collect-garbage --dry-run`               | Estimer ce que le garbage collector peut supprimer                                          |
| `nix-collect-garbage -d`                      | Supprimer les anciennes générations non protégées et collecter les chemins devenus inutiles |
| `nix-collect-garbage --delete-older-than 30d` | Supprimer les anciennes générations selon leur âge, puis collecter les chemins inutilisés   |
| `sudo nix-collect-garbage -d`                 | Effectuer le nettoyage système avec les privilèges nécessaires                              |
| `nix store optimise`                          | Dédupliquer les fichiers identiques du store grâce aux liens physiques                      |

Attention à `-d` : cette option peut supprimer tes anciennes générations et réduire tes possibilités de rollback. Sur NixOS, vérifie les générations que tu souhaites conserver avant de l'utiliser.

## 6. Comprendre l'impact réel sur le disque

Ces trois mesures répondent à des questions différentes :

Espace réellement disponible

```
df -h /nix/store
```

C'est la mesure à surveiller pour savoir si ton disque se remplit.

Taille apparente des fichiers

```
du -sh /nix/store
```

Utile pour comparer les répertoires, mais ne représente pas toujours l'espace physique unique consommé.

Gain de déduplication potentiel

```
nix store optimise
```

Nix peut partager physiquement des fichiers identiques. Cela économise de l'espace sans supprimer de paquets.

## 7. Routine de diagnostic recommandée

Tu peux exécuter cette séquence dans ton terminal :

```
# 1. Espace disponible
df -h /nix

# 2. Taille apparente du store
du -sh /nix/store

# 3. Principaux répertoires volumineux
du -sh /nix/store/* 2>/dev/null | sort -h | tail -20

# 4. Racines qui protègent des chemins
nix-store --gc --print-roots

# 5. Simulation du nettoyage
nix-collect-garbage --dry-run

# 6. Taille de la closure du système actif
nix path-info --recursive --size /run/current-system
```

La dernière commande est intéressante pour ton environnement NixOS : elle permet d'examiner la fermeture du système actuellement activé, mais pas nécessairement toutes les générations historiques qui occupent le store.

Le principe à retenir : pour libérer de l'espace, il faut identifier les chemins devenus inaccessibles depuis les racines, et pas simplement supprimer les paquets les plus volumineux. Les closures et les générations expliquent pourquoi une partie du store reste présente même lorsque tu n'utilises plus directement certains logiciels.


## 8. Cas d'un système Linux qui n'est pas NixOS

Sur une distribution comme EndeavourOS, Arch Linux, Debian ou Ubuntu, le store Nix fonctionne indépendamment du système d'exploitation. Tu peux donc analyser et nettoyer Nix sans toucher aux paquets gérés par `pacman`, `apt` ou un autre gestionnaire système.

### 8.1 Vérifier l'installation Nix

```
# Version de Nix
nix --version

# Configuration et informations sur le store
nix store info

# Emplacement habituel du store
ls -ld /nix/store

# Espace disque
df -h /nix/store
du -sh /nix/store
```

Sur un Linux multi-utilisateur, le store est généralement partagé entre les utilisateurs et géré par le démon Nix.

### 8.2 Examiner les profils et les générations

C'est la principale différence avec NixOS : tu n'as pas de générations de système NixOS à gérer, mais tu peux avoir des générations de profils Nix.

```
# Afficher les profils disponibles
nix profile list

# Historique du profil utilisateur courant
nix profile history

# Afficher les profils et racines enregistrés
nix-store --query --roots /nix/store/chemin-du-paquet
```

La dernière commande permet de retrouver les racines qui référencent un chemin précis. Remplace le chemin d'exemple par celui du paquet étudié.

Si tu utilises l'ancien système de profils (`nix-env`), tu peux aussi exécuter :

```
nix-env --list-generations
```

Les commandes `nix profile` et `nix-env` correspondent à deux interfaces de gestion des profils : ne suppose pas que les deux gèrent le même profil.

### 8.3 Mesurer les paquets et leurs dépendances

```
# Classer les plus gros chemins
nix path-info --all --size \
  | sort -k2,2n \
  | tail -30

# Examiner les dépendances d'un paquet installé
nix-store --query --requisites /nix/store/…-mon-paquet

# Identifier les références entrantes
nix-store --query --referrers /nix/store/…-mon-paquet

# Trouver la raison d'une dépendance
nix why-depends \
  /nix/store/…-mon-paquet \
  /nix/store/…-dependance
```

Pour `nix why-depends`, les deux chemins doivent être cohérents : le premier doit dépendre du second, directement ou indirectement.

### 8.4 Nettoyer le store sans NixOS

Sans risque de suppression immédiate

Simuler le garbage collector

```
nix-collect-garbage --dry-run
```

Cette simulation permet d'estimer ce qui est collectable sans effectuer le nettoyage.

Supprimer les anciennes générations et collecter les chemins inutilisés

```
nix-collect-garbage -d
```

Cette commande peut supprimer les anciennes générations de profils concernés. Vérifie tes besoins de rollback avant de l'exécuter.

Optimiser l'espace par déduplication

```
nix store optimise
```

Cette opération cherche à partager les fichiers identiques du store ; elle ne supprime pas les paquets installés.

### 8.5 Comprendre les différences avec NixOS

| Sujet                               | Linux classique avec Nix                         | NixOS                                    |
| ----------------------------------- | ------------------------------------------------ | ---------------------------------------- |
| Store `/nix/store`                  | Oui                                              | Oui                                      |
| Profils utilisateur                 | Oui                                              | Oui                                      |
| Générations système NixOS           | Non                                              | Oui                                      |
| `/run/current-system`               | Généralement absent                              | Référence au système activé              |
| Garbage collector                   | Oui                                              | Oui                                      |
| Rollback complet du système via Nix | Dépend de la distribution et de la configuration | Pris en charge par les générations NixOS |

À retenir : sur EndeavourOS, par exemple, concentre-toi sur `/nix/store`, les profils Nix, les racines et le garbage collector. N'utilise pas les commandes de gestion des générations système NixOS si ton système d'exploitation n'est pas NixOS.

```bash
# 1. Supprime tous les profils et environnements de développement temporaires (gcroots)
sudo rm -rf /nix/var/nix/gcroots/auto/*

# 2. Force la suppression absolue de tout ce qui n'est pas utilisé à l'instant T
sudo nix-collect-garbage -d

```
