#!/bin/bash

# Fonction d'aide
usage() {
    echo "Usage: $0 [-f] [-s] [-t] [-r path]"
    echo "  -f : Fork (Update & Scan fichiers >100Mo)"
    echo "  -s : Subshell (Usage disque par utilisateur)"
    echo "  -t : Thread (Appel du script C externe)"
    echo "  -r : Restore (Réinitialiser les permissions)"
    exit 1
}

# Vérification des arguments
if [ $# -eq 0 ]; then usage; fi

while getopts "fstr:" opt; do
    case $opt in
        f)
            echo "--- Lancement du Fork (Parallélisation) ---"
            # Tâche 1 : Mises à jour (en arrière-plan)
            (echo "Mise à jour système..."; sudo apt update -y > /dev/null 2>&1) &
            # Tâche 2 : Scan fichiers volumineux
            (echo "Scan des fichiers >100Mo..."; find / -type f -size +100M 2>/dev/null) &
            wait
            echo "Terminé."
            ;;
        s)
            echo "--- Calcul disque (Subshell) ---"
            (
                # Les variables ici ne modifieront pas l'environnement parent
                export TMP_VAR="Analyse_Locale"
                echo "Contexte : $TMP_VAR"
                cut -d: -f1,3 /etc/passwd | awk -F: '$2 >= 1000 {print $1}' | while read user; do
                    echo -n "Utilisateur $user : "
                    du -sh /home/$user 2>/dev/null || echo "Inaccessible"
                done
            )
            echo "Retour au script principal (Subshell fermé)."
            ;;
        t)
            echo "--- Vérification Réseau (Threads C) ---"
            if [ -f "./port_check" ]; then
                ./port_check
            else
                echo "Erreur : Le binaire 'port_check' est introuvable. Compilez port_check.c d'abord."
            fi
            ;;
        r)
            TARGET_DIR=${OPTARG:-"/var/www"}
            echo "--- Restauration des permissions sur $TARGET_DIR ---"
            if [ -d "$TARGET_DIR" ]; then
                sudo chown -R www-data:www-data "$TARGET_DIR"
                sudo find "$TARGET_DIR" -type d -exec chmod 755 {} \;
                sudo find "$TARGET_DIR" -type f -exec chmod 644 {} \;
                echo "Permissions restaurées (D:755, F:644)."
            else
                echo "Erreur : Le dossier $TARGET_DIR n'existe pas."
            fi
            ;;
        *)
            usage
            ;;
    esac
done
