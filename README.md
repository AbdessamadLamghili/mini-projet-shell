# Module Surveillance Sécurité — TrinityOps

**Auteur : Nour**
**Projet : Mini Projet Shell**

---

## Description

Ce module surveille la sécurité du système Linux. Il analyse les tentatives de connexion SSH, détecte les attaques brute force, et vérifie l'intégrité des fichiers critiques. Il démontre les mécanismes fork, thread simulé et subshell en Bash.

---

## Usage

```bash
sudo bash module_securite.sh [OPTION]
```

## Options

```
-h   Afficher l'aide
-f   FORK    : surveillance SSH en parallèle
-t   THREAD  : détection d'attaques brute force
-s   SUBSHELL: vérification d'intégrité MD5
-l   LOG     : afficher le journal de sécurité
```

## Exemples

```bash
sudo bash module_securite.sh -h
sudo bash module_securite.sh -f
sudo bash module_securite.sh -t
sudo bash module_securite.sh -s
sudo bash module_securite.sh -l
```

---

## Mécanismes démontrés

**Fork (`-f`)** : trois processus lancés en parallèle via `( ) &` pour analyser simultanément les connexions SSH réussies, échouées, et les dernières activités. Chaque fork a son propre PID.

**Thread simulé (`-t`)** : deux analyses lancées en parallèle — l'une par adresse IP, l'autre par heure d'attaque. Si une IP dépasse 3 tentatives, une alerte ERROR est enregistrée.

**Subshell (`-s`)** : vérification des empreintes MD5 de `/etc/passwd`, `/etc/shadow`, `/etc/hosts` et `/bin/bash` dans un environnement isolé `( )`. Toute modification détectée déclenche une alerte.

---

## Journal

Toutes les actions sont enregistrées dans `/var/log/module_securite/history.log` :

```
yyyy-mm-dd-hh-mm-ss : utilisateur : NIVEAU : message
```

## Codes d'erreur

```
100 : Option invalide
101 : Impossible de créer le dossier de log
102 : Droits root requis
103 : Fichier auth.log introuvable
```

---

## Prérequis

Ubuntu 20.04+, Bash 4.0+, droits root
