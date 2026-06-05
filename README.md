# TrinityOps : Mini Projet Shell

**Équipe : Team-A04 | ENSET Mohammedia 2026**  
**Encadrant : Pr. Abdellah Ouaguid**

> « Un script Bash modulaire unifiant trois volets : maintenance, sécurité et gestion de données. »

---

## Membres

| Nom | Module | Script |
|-----|--------|--------|
| Abdessamad Lamghili | Orchestrateur global | `main.sh` |
| Ali Daaif | Maintenance système | `scripts/auto_maintenance.sh` |
| Bassma Lamalem | Gestion de données | `scripts/data_focus.sh` |
| Nour Lahrach | Surveillance sécurité | `scripts/module_securite.sh` |

---

## Architecture

```
mini-projet-shell/
├── main.sh                        ← Orchestrateur global
├── scripts/
│   ├── auto_maintenance.sh        ← Module maintenance (Ali)
│   ├── data_focus.sh              ← Module données (Bassma)
│   └── module_securite.sh         ← Module sécurité (Nour)
├── port_scanner.c                 ← Scanner ports multi-thread C (Ali)
├── port_check.c                   ← Scanner ports simplifié (Ali)
└── README.md
```

---

## Utilisation

### Script global

```bash
# Mode normal
./main.sh /tmp/data

# Mode fork (modules en parallèle)
./main.sh -f /tmp/data

# Mode thread (parallélisme simulé)
./main.sh -t /tmp/data

# Mode subshell (environnement isolé)
./main.sh -s /tmp/data

# Restauration (root requis)
sudo ./main.sh -r /tmp/data
```

### Module sécurité (Nour)

```bash
sudo bash scripts/module_securite.sh -h   # Aide
sudo bash scripts/module_securite.sh -f   # Fork SSH
sudo bash scripts/module_securite.sh -t   # Détection brute force
sudo bash scripts/module_securite.sh -s   # Vérification MD5
sudo bash scripts/module_securite.sh -l   # Journal
sudo bash scripts/module_securite.sh -w 30  # Watchmode 30s
sudo bash scripts/module_securite.sh -r   # Restauration
```

### Module maintenance (Ali)

```bash
./scripts/auto_maintenance.sh -f              # Fork : mises à jour + scan
./scripts/auto_maintenance.sh -s              # Subshell : espace disque
./scripts/auto_maintenance.sh -t "22,80,443"  # Thread C : scan ports
sudo ./scripts/auto_maintenance.sh -r /var/www  # Restauration
```

### Module données (Bassma)

```bash
./scripts/data_focus.sh -f   # Fork : tri par extension
./scripts/data_focus.sh -t   # Thread : chiffrement fichiers
./scripts/data_focus.sh -s   # Subshell : rapport statistique
./scripts/data_focus.sh -r   # Restauration
./scripts/data_focus.sh -c   # Compression archive
./scripts/data_focus.sh -x   # Extraction dernière archive
```

---

## Mécanismes démontrés

- **Fork** `( ) &` — processus enfants indépendants en parallèle
- **Thread simulé** `& wait` — sous-processus parallèles (Bash ne supporte pas les threads natifs)
- **Thread POSIX** — programme C avec `pthread` (module maintenance)
- **Subshell** `( )` — environnement isolé séquentiel

---

## Prérequis

```bash
Ubuntu 20.04+, Bash 4.0+, gcc, sudo
```

---

*Team-A04 — TrinityOps — ENSET Mohammedia 2026*
