# TrinityOPS - Orchestrateur de Maintenance, Sécurité et Gestion des Données

## Description du Projet

TrinityOPS est un projet Bash développé dans le cadre du module **Théorie des Systèmes d’Exploitation & SE Windows/Unix/Linux** à l’ENSET Mohammedia.

Le projet regroupe trois scripts spécialisés :

1. **auto_maintenance.sh** – Maintenance système
2. **data_focus.sh** – Gestion et traitement des données
3. **module_securite.sh** – Surveillance de sécurité

Le script principal **main.sh** joue le rôle d’orchestrateur. Il centralise l’exécution de tous les modules selon différents modes : normal, fork, thread et subshell.

---

## Objectifs

- Automatiser des tâches d’administration système.
- Organiser, archiver et sécuriser les données.
- Surveiller les activités suspectes du système.
- Démontrer les concepts de :
  - Processus (fork)
  - Threads
  - Subshell
  - Permissions
  - Journalisation
  - Gestion des erreurs

---

## Architecture du Projet

```text
mini-projet-shell/
├── main.sh
├── README.md
├── README_module_securite.md
├── scripts/
│   ├── auto_maintenance.sh
│   ├── data_focus.sh
│   ├── module_securite.sh
│   └── port_scanner.c
├── logs/
│   └── history.log
└── archives/