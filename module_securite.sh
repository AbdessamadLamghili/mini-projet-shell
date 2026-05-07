#!/bin/bash
# ============================================
# module_securite.sh - Surveillance sécurité
# TrinityOps - Module 3
# ============================================

LOG_DIR="/var/log/module_securite"
LOG_FILE="$LOG_DIR/history.log"
REFERENCE_MD5="/tmp/trinity_md5_reference.txt"
SEUIL_BRUTE=3

ERR_NONE=0
ERR_OPTION=100
ERR_LOG_DIR=101
ERR_PERMISSION=102
ERR_AUTH_LOG=103

# ============================================
# Fonction log()
# ============================================
log() {
    local niveau="$1"
    local message="$2"
    local horodatage=$(date "+%Y-%m-%d-%H-%M-%S")
    local utilisateur=$(whoami)
    local entree="$horodatage : $utilisateur : $niveau : $message"
    echo "$entree" >> "$LOG_FILE"
    if [ "$niveau" = "ERROR" ]; then
        echo "ERREUR: $message" >&2
    else
        echo "$message"
    fi
}

# ============================================
# Fonction init()
# ============================================
init() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Impossible de créer $LOG_DIR — relance avec sudo"
        exit $ERR_LOG_DIR
    fi
    touch "$LOG_FILE"
    log "INFO" "=== Module sécurité démarré ==="
}

# ============================================
# Fonction verifier_root()
# ============================================
verifier_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script nécessite les droits root."
        echo "Relance avec : sudo bash module_securite.sh [flag]"
        exit $ERR_PERMISSION
    fi
    log "INFO" "Vérification root : OK (UID=$EUID)"
}

# ============================================
# Fonction afficher_aide()
# ============================================
afficher_aide() {
    cat << EOF
========================================
  module_securite.sh - Module sécurité
========================================
USAGE: sudo bash module_securite.sh [OPTION]

OPTIONS:
  -h   Afficher cette aide
  -f   FORK    : Surveillance des connexions SSH en parallèle
  -t   THREAD  : Détection d'attaques brute force
  -s   SUBSHELL: Vérification d'intégrité MD5 des fichiers
  -l   LOG     : Afficher le journal de sécurité

CODES D'ERREUR:
  100 : Option invalide
  101 : Impossible de créer le dossier de log
  102 : Droits root requis
  103 : Fichier auth.log introuvable

EXEMPLES:
  sudo bash module_securite.sh -f
  sudo bash module_securite.sh -t
  sudo bash module_securite.sh -s
  sudo bash module_securite.sh -l

LOG: $LOG_FILE
EOF
}

# ============================================
# Fonction surveillance_ssh_fork()
# ============================================
surveillance_ssh_fork() {
    log "INFO" "=== Surveillance SSH démarrée (fork) ==="
    echo "Processus parent PID : $$"

    if [ ! -f /var/log/auth.log ]; then
        log "ERROR" "Fichier auth.log introuvable"
        exit $ERR_AUTH_LOG
    fi

    local tmp1=$(mktemp)
    local tmp2=$(mktemp)
    local tmp3=$(mktemp)

    # Fork 1 : connexions réussies
    (
        echo "--- [Fork PID $BASHPID, parent $$] Connexions SSH réussies ---" > $tmp1
        resultat=$(grep "Accepted" /var/log/auth.log | tail -5)
        if [ -z "$resultat" ]; then
            echo "Aucune connexion réussie trouvée" >> $tmp1
        else
            echo "$resultat" >> $tmp1
        fi
        log "INFO" "Fork 1 (PID $BASHPID) terminé"
    ) &

    # Fork 2 : connexions échouées
    (
        echo "--- [Fork PID $BASHPID, parent $$] Connexions SSH échouées ---" > $tmp2
        resultat=$(grep "Failed password" /var/log/auth.log | tail -5)
        if [ -z "$resultat" ]; then
            echo "Aucune connexion échouée trouvée" >> $tmp2
        else
            echo "$resultat" >> $tmp2
        fi
        log "INFO" "Fork 2 (PID $BASHPID) terminé"
    ) &

    # Fork 3 : dernières activités SSH
    (
        echo "--- [Fork PID $BASHPID, parent $$] Dernières activités SSH ---" > $tmp3
        resultat=$(grep "sshd" /var/log/auth.log | tail -5)
        if [ -z "$resultat" ]; then
            echo "Aucune activité SSH trouvée" >> $tmp3
        else
            echo "$resultat" >> $tmp3
        fi
        log "INFO" "Fork 3 (PID $BASHPID) terminé"
    ) &

    wait

    # Affichage propre après que tous les forks sont terminés
    cat $tmp1
    echo ""
    cat $tmp2
    echo ""
    cat $tmp3

    rm -f $tmp1 $tmp2 $tmp3
    log "INFO" "=== Surveillance SSH terminée ==="
    echo ""
    echo "Terminé. Résultats dans : $LOG_FILE"
}

# ============================================
# Fonction : analyser_bruteforce()
# ============================================
analyser_bruteforce() {
    log "INFO" "=== Analyse brute force démarrée (thread simulé) ==="

    if [ ! -f /var/log/auth.log ]; then
        log "ERROR" "Fichier auth.log introuvable"
        exit $ERR_AUTH_LOG
    fi

    # Thread 1 : analyse des échecs par IP
    (
        echo "--- [Thread PID $BASHPID, parent $$] Analyse par IP ---"

        # Compter les échecs par IP
        resultats=$(grep "Failed password" /var/log/auth.log \
            | awk '{print $11}' \
            | sort | uniq -c \
            | sort -rn)

        if [ -z "$resultats" ]; then
            echo "Aucune tentative échouée trouvée"
            log "INFO" "Aucune attaque détectée"
        else
            echo "IP suspectes (nombre de tentatives) :"
            echo "$resultats"

            # Vérifier si une IP dépasse le seuil
            while read count ip; do
                if [ "$count" -ge "$SEUIL_BRUTE" ]; then
                    echo "ALERTE : $ip a tenté $count fois !"
                    log "ERROR" "BRUTE FORCE détecté : $ip — $count tentatives"
                fi
            done <<< "$resultats"
        fi

        log "INFO" "Thread analyse (PID $BASHPID) terminé"
    ) &

    # Thread 2 : analyse des échecs par heure
    (
        echo "--- [Thread PID $BASHPID, parent $$] Analyse par heure ---"
        resultats=$(grep "Failed password" /var/log/auth.log \
            | awk '{print $3}' \
            | cut -d: -f1 \
            | sort | uniq -c \
            | sort -rn)

        if [ -z "$resultats" ]; then
            echo "Aucune donnée horaire trouvée"
            log "INFO" "Thread 2 : aucune donnée horaire"
        else
            echo "Heures les plus attaquées :"
            echo "$resultats"
            log "INFO" "Thread 2 : analyse horaire terminée"
        fi
        log "INFO" "Thread 2 (PID $BASHPID) terminé"
    ) &

    wait
    log "INFO" "=== Analyse brute force terminée ==="
    echo "Analyse terminée. Résultats dans : $LOG_FILE"
}

# ============================================
# Fonction : verifier_md5()
# ============================================
verifier_md5() {
    log "INFO" "=== Vérification MD5 démarrée (subshell) ==="

    local fichiers=(
        "/etc/passwd"
        "/etc/shadow"
        "/etc/hosts"
        "/bin/bash"
    )

    # Tout se passe dans un subshell isolé
    (
        echo "--- [Subshell PID $BASHPID, parent $$] Vérification MD5 ---"

        # Phase 1 : si pas de référence, on la crée
        if [ ! -f "$REFERENCE_MD5" ]; then
            echo "Première exécution — génération des empreintes de référence..."
            for fichier in "${fichiers[@]}"; do
                if [ -f "$fichier" ]; then
                    md5sum "$fichier" >> "$REFERENCE_MD5"
                    echo "Référence créée : $fichier"
                fi
            done
            log "INFO" "Empreintes de référence générées dans $REFERENCE_MD5"
            echo "Référence sauvegardée. Relance -s pour vérifier."
        else
            # Phase 2 : on compare avec la référence
            echo "Vérification des empreintes..."
            alerte=0
            for fichier in "${fichiers[@]}"; do
                if [ -f "$fichier" ]; then
                    # Calculer l'empreinte actuelle
                    empreinte_actuelle=$(md5sum "$fichier" | awk '{print $1}')
                    # Chercher l'empreinte de référence
                    empreinte_reference=$(grep "$fichier" "$REFERENCE_MD5" | awk '{print $1}')

                    if [ -z "$empreinte_reference" ]; then
                        echo "NOUVEAU fichier détecté : $fichier"
                        md5sum "$fichier" >> "$REFERENCE_MD5"
                    elif [ "$empreinte_actuelle" = "$empreinte_reference" ]; then
                        echo "OK : $fichier"
                        log "INFO" "Intégrité OK : $fichier"
                    else
                        echo "ALERTE : $fichier a été modifié !"
                        log "ERROR" "FICHIER MODIFIÉ : $fichier"
                        alerte=1
                    fi
                fi
            done

            if [ "$alerte" -eq 0 ]; then
                echo "Tous les fichiers sont intègres."
            fi
        fi

        log "INFO" "Subshell MD5 (PID $BASHPID) terminé"
    )

    log "INFO" "=== Vérification MD5 terminée ==="
    echo "Vérification terminée. Résultats dans : $LOG_FILE"
}

# ============================================
# Fonction : afficher_logs()
# ============================================
afficher_logs() {
    log "INFO" "=== Affichage du journal de sécurité ==="

    if [ ! -f "$LOG_FILE" ]; then
        echo "Aucun journal trouvé dans $LOG_FILE"
        exit $ERR_LOG_DIR
    fi

    echo "========================================"
    echo "  Journal de sécurité - module_securite"
    echo "========================================"
    echo ""

    # Afficher les erreurs en premier
    echo "--- ALERTES ---"
    grep "ERROR" "$LOG_FILE" || echo "Aucune alerte"
    echo ""

    # Afficher tout le journal
    echo "--- JOURNAL COMPLET ---"
    cat "$LOG_FILE"
    echo ""
    echo "Total lignes : $(wc -l < $LOG_FILE)"
}


# ============================================
# Point d'entrée principal
# ============================================
init
verifier_root

if [ $# -eq 0 ]; then
    echo "Aucune option fournie."
    afficher_aide
    exit $ERR_OPTION
fi

while getopts ":hftsl" opt; do
    case $opt in
        h) afficher_aide ;;
        f) surveillance_ssh_fork ;;
        t) analyser_bruteforce ;;
        s) verifier_md5 ;;
        l) afficher_logs ;;
        \?) echo "Option invalide : -$OPTARG. Utilise -h pour l'aide."
            exit $ERR_OPTION ;;
    esac
done

exit $ERR_NONE
