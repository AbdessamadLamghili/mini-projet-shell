#!/usr/bin/env bash
# ==============================================================================
# SCRIPT PRINCIPAL ORCHESTRATEUR - MINI PROJET ENSET MOHAMMEDIA 2026
# ==============================================================================
# Nom du programme  : main.sh
# Module            : Théorie des systèmes d'exploitation & SE Windows/Unix/Linux
# Description       : Script global qui orchestre l'exécution des scripts métiers
#                     des membres du groupe selon le mode choisi (normal/fork/
#                     thread/subshell).
# Syntaxe           : ./main.sh [options] TARGET_DIR
# Auteur            : [Votre Nom] - [Votre Équipe]
# Version           : 1.0
# Date              : 2026
# ==============================================================================

# ==============================================================================
# SECTION 1 : VARIABLES GLOBALES
# ==============================================================================

# Nom du programme (utilisé dans les messages et les logs)
readonly PROG_NAME="$(basename "$0")"

# Version du script
readonly VERSION="1.0"

# Répertoire de base du projet (répertoire où se trouve main.sh)
readonly BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Répertoire des scripts des collègues
readonly SCRIPTS_DIR="${BASE_DIR}/scripts"

# Répertoire de logs par défaut (peut être surchargé par -l)
DEFAULT_LOG_DIR="${BASE_DIR}/logs"

# Répertoire de logs actif (modifiable via -l)
LOG_DIR="${DEFAULT_LOG_DIR}"

# Fichier de log principal
LOG_FILE=""   # Sera défini après parsing des options

# Paramètre obligatoire : répertoire cible à traiter
TARGET_DIR=""

# Mode d'exécution : normal (défaut), fork, thread, subshell
EXEC_MODE="normal"

# Drapeau pour l'option restore
OPT_RESTORE=false

# Codes de retour / codes d'erreur explicites
readonly ERR_INVALID_OPTION=100
readonly ERR_MISSING_PARAM=101
readonly ERR_NOT_ADMIN=102
readonly ERR_MISSING_SCRIPT=103
readonly ERR_INVALID_DIR=104
readonly ERR_MODULE_FAILED=105
readonly ERR_LOG_INIT=106

# ------------------------------------------------------------------
# Chemins des trois scripts métiers du groupe
# ------------------------------------------------------------------
readonly SCRIPT_MAINTENANCE="${SCRIPTS_DIR}/auto_maintenance.sh"   # Projet 1 – Automate de Maintenance Système
readonly SCRIPT_DATA="${SCRIPTS_DIR}/data_focus.sh"                # Projet 4 – Organisateur de Données Big Data
readonly SCRIPT_SECURITE="${SCRIPTS_DIR}/module_securite.sh"       # Projet 3 – Surveillant de Sécurité & Intrusion

# Tableau ordonné utilisé pour les vérifications de dépendances
COLLEAGUE_SCRIPTS=(
    "${SCRIPT_MAINTENANCE}"
    "${SCRIPT_DATA}"
    "${SCRIPT_SECURITE}"
)

# ==============================================================================
# SECTION 2 : FONCTION D'AIDE (option -h)
# ==============================================================================

show_help() {
    # Affichage de la documentation complète du programme (style man Linux)
    cat <<EOF

NOM
    ${PROG_NAME} - Orchestrateur de traitements automatisés (Mini Projet ENSET 2026)

SYNOPSIS
    ${PROG_NAME} [OPTIONS] TARGET_DIR

DESCRIPTION
    Script Bash principal qui coordonne l'exécution de trois modules spécialisés
    développés par les membres du groupe :
        • auto_maintenance.sh  – Automate de Maintenance Système
        • data_focus.sh        – Organisateur de Données Big Data
        • module_securite.sh   – Surveillant de Sécurité & Intrusion

    TARGET_DIR   Répertoire cible obligatoire sur lequel les modules vont opérer.
                 Ce répertoire doit exister et être accessible en lecture.

OPTIONS
    -h           Affiche cette aide détaillée et quitte.

    -f           Mode FORK : chaque module est exécuté dans un sous-processus
                 indépendant (& + wait). Permet la parallélisation des traitements.

    -t           Mode THREAD : simulation de parallélisme en Bash via sous-processus
                 en arrière-plan. Équivalent fonctionnel au mode fork en Bash pur.

    -s           Mode SUBSHELL : les modules sont exécutés dans un sous-shell
                 isolé (entre parenthèses). L'environnement du shell parent est préservé.

    -l LOG_DIR   Spécifie un répertoire personnalisé pour le fichier de log
                 history.log. Par défaut : ${DEFAULT_LOG_DIR}

    -r           RESTORE : appelle les modules qui supportent la restauration.
                 NÉCESSITE LES PRIVILÈGES ROOT/ADMINISTRATEUR.

FORMAT DES LOGS
    Chaque entrée dans history.log suit le format :
        yyyy-mm-dd-hh-mm-ss : username : INFOS : message
        yyyy-mm-dd-hh-mm-ss : username : ERROR : message

CODES D'ERREUR
    ${ERR_INVALID_OPTION}   Option invalide ou inconnue
    ${ERR_MISSING_PARAM}   Paramètre obligatoire manquant (TARGET_DIR)
    ${ERR_NOT_ADMIN}   Privilèges insuffisants (root requis)
    ${ERR_MISSING_SCRIPT}   Script externe (module collègue) introuvable
    ${ERR_INVALID_DIR}   Répertoire invalide ou inaccessible
    ${ERR_MODULE_FAILED}   Échec d'exécution d'un module
    ${ERR_LOG_INIT}   Impossible d'initialiser le répertoire de logs

EXEMPLES
    # Exécution normale sur /tmp/data
    ./${PROG_NAME} /tmp/data

    # Exécution en mode fork avec log personnalisé
    ./${PROG_NAME} -f -l /tmp/logs /tmp/data

    # Exécution en mode subshell
    ./${PROG_NAME} -s /tmp/data

    # Exécution en mode thread
    ./${PROG_NAME} -t /tmp/data

    # Restauration (root uniquement)
    sudo ./${PROG_NAME} -r /tmp/data

    # Afficher l'aide
    ./${PROG_NAME} -h

ARCHITECTURE DU PROJET
    project/
    ├── main.sh                      ← Ce script (orchestrateur)
    ├── scripts/
    │   ├── auto_maintenance.sh      ← Module 1 – Maintenance Système
    │   ├── data_focus.sh            ← Module 4 – Big Data
    │   └── module_securite.sh       ← Module 3 – Sécurité & Intrusion
    └── logs/
        └── history.log              ← Journal centralisé

VERSION
    ${PROG_NAME} version ${VERSION} - ENSET Mohammedia 2026

EOF
}

# ==============================================================================
# SECTION 3 : FONCTIONS DE JOURNALISATION
# ==============================================================================

# Fonction interne : génère un horodatage au format yyyy-mm-dd-hh-mm-ss
_timestamp() {
    date "+%Y-%m-%d-%H-%M-%S"
}

# Fonction interne : retourne le nom de l'utilisateur courant
_username() {
    echo "${USER:-$(whoami)}"
}

# log_info : journalise un message de type INFOS
# Usage : log_info "message"
log_info() {
    local message="$1"
    local entry="$(_timestamp) : $(_username) : INFOS : ${message}"
    echo "${entry}"
    if [[ -n "${LOG_FILE}" ]]; then
        echo "${entry}" >> "${LOG_FILE}"
    fi
}

# log_error : journalise un message de type ERROR
# Usage : log_error "message"
log_error() {
    local message="$1"
    local entry="$(_timestamp) : $(_username) : ERROR : ${message}"
    echo "${entry}" >&2
    if [[ -n "${LOG_FILE}" ]]; then
        echo "${entry}" >> "${LOG_FILE}"
    fi
}

# ==============================================================================
# SECTION 4 : FONCTION DE CONTRÔLE D'ACCÈS ADMINISTRATEUR
# ==============================================================================

# check_admin : vérifie que le script est exécuté par root (UID=0)
check_admin() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "L'option -r (restore) nécessite les privilèges administrateur (root)."
        log_error "Veuillez relancer avec : sudo ${PROG_NAME} -r ${TARGET_DIR}"
        show_help
        exit "${ERR_NOT_ADMIN}"
    fi
    log_info "Vérification des privilèges administrateur : OK (UID=${EUID})"
}

# ==============================================================================
# SECTION 5 : FONCTION DE VÉRIFICATION DES DÉPENDANCES (scripts collègues)
# ==============================================================================

# check_dependencies : vérifie que tous les scripts collègues sont présents
# et exécutables. Si un script existe mais n'est pas exécutable, corrige les
# permissions automatiquement. Quitte avec ERR_MISSING_SCRIPT si introuvable.
check_dependencies() {
    log_info "Vérification des modules externes (scripts collègues)..."
    local all_ok=true

    for script in "${COLLEAGUE_SCRIPTS[@]}"; do
        if [[ -f "${script}" && -x "${script}" ]]; then
            log_info "  [OK] Module trouvé et exécutable : ${script}"
        elif [[ -f "${script}" && ! -x "${script}" ]]; then
            log_error "  [WARN] Module non exécutable : ${script} — Tentative de correction..."
            chmod +x "${script}" 2>/dev/null \
                && log_info "  [OK] Permissions corrigées : ${script}" \
                || { log_error "  [ERR] Impossible de corriger les permissions : ${script}"; all_ok=false; }
        else
            log_error "  [MANQUANT] Module introuvable : ${script}"
            all_ok=false
        fi
    done

    if [[ "${all_ok}" == false ]]; then
        log_error "Un ou plusieurs modules sont manquants. Vérifiez l'arborescence du projet."
        show_help
        exit "${ERR_MISSING_SCRIPT}"
    fi

    log_info "Tous les modules sont présents et prêts."
}

# ==============================================================================
# SECTION 6 : FONCTION D'INITIALISATION DU RÉPERTOIRE DE LOGS
# ==============================================================================

# init_log : crée le répertoire de logs s'il n'existe pas et initialise LOG_FILE
init_log() {
    if [[ ! -d "${LOG_DIR}" ]]; then
        mkdir -p "${LOG_DIR}" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "ERREUR : Impossible de créer le répertoire de logs : ${LOG_DIR}" >&2
            echo "Conseil : essayez avec sudo, ou spécifiez un autre dossier avec -l" >&2
            show_help
            exit "${ERR_LOG_INIT}"
        fi
    fi

    LOG_FILE="${LOG_DIR}/history.log"

    touch "${LOG_FILE}" 2>/dev/null || {
        echo "ERREUR : Impossible de créer le fichier de log : ${LOG_FILE}" >&2
        exit "${ERR_LOG_INIT}"
    }

    log_info "Journalisation initialisée → ${LOG_FILE}"
}

# ==============================================================================
# SECTION 7 : FONCTION RESTORE (option -r, admin uniquement)
# ==============================================================================

# restore_defaults : appelle auto_maintenance.sh -r et data_focus.sh -r
# module_securite.sh ne supporte pas -r et n'est donc pas appelé.
restore_defaults() {
    log_info "=== DÉBUT DE LA RESTAURATION ==="
    log_info "Répertoire cible : ${TARGET_DIR}"

    # --- auto_maintenance.sh : supporte -r avec TARGET_DIR ---
    log_info "[RESTORE] Appel de auto_maintenance.sh -r \"${TARGET_DIR}\""
    bash "${SCRIPT_MAINTENANCE}" -r "${TARGET_DIR}"
    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log_error "[RESTORE] auto_maintenance.sh a échoué (code: ${rc})"
    else
        log_info "[RESTORE] auto_maintenance.sh terminé avec succès."
    fi

    # --- data_focus.sh : supporte -r (sans argument supplémentaire) ---
    log_info "[RESTORE] Appel de data_focus.sh -r"
    bash "${SCRIPT_DATA}" -r
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log_error "[RESTORE] data_focus.sh a échoué (code: ${rc})"
    else
        log_info "[RESTORE] data_focus.sh terminé avec succès."
    fi

    # --- module_securite.sh : pas d'option -r → non appelé ---
    log_info "[RESTORE] module_securite.sh ne supporte pas -r → ignoré."

    log_info "=== RESTAURATION TERMINÉE ==="
}

# ==============================================================================
# SECTION 8 : FONCTIONS D'EXÉCUTION DES MODULES PAR MODE
# ==============================================================================

# ---------------------------------------------------------------------------
# run_normal : exécution séquentielle — appel de chaque script avec -h
# Le mode normal affiche l'aide de chaque module l'un après l'autre.
# ---------------------------------------------------------------------------
run_normal() {
    log_info "=== MODE NORMAL : exécution séquentielle ==="
    local global_status=0

    # auto_maintenance.sh -h
    log_info "  → auto_maintenance.sh -h"
    bash "${SCRIPT_MAINTENANCE}" -h
    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log_error "  ✗ auto_maintenance.sh a échoué (code: ${rc})"
        global_status="${ERR_MODULE_FAILED}"
    else
        log_info "  ✓ auto_maintenance.sh terminé avec succès."
    fi

    # data_focus.sh -h
    log_info "  → data_focus.sh -h"
    bash "${SCRIPT_DATA}" -h
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log_error "  ✗ data_focus.sh a échoué (code: ${rc})"
        global_status="${ERR_MODULE_FAILED}"
    else
        log_info "  ✓ data_focus.sh terminé avec succès."
    fi

    # module_securite.sh -h
    log_info "  → module_securite.sh -h"
    bash "${SCRIPT_SECURITE}" -h
    rc=$?
    if [[ ${rc} -ne 0 ]]; then
        log_error "  ✗ module_securite.sh a échoué (code: ${rc})"
        global_status="${ERR_MODULE_FAILED}"
    else
        log_info "  ✓ module_securite.sh terminé avec succès."
    fi

    if [[ ${global_status} -ne 0 ]]; then
        log_error "Un ou plusieurs modules ont échoué en mode normal."
        exit "${global_status}"
    fi
    log_info "=== MODE NORMAL : tous les modules terminés ==="
}

# ---------------------------------------------------------------------------
# run_fork : exécution parallèle via sous-processus (fork & + wait)
# Chaque module est lancé avec l'option -f en arrière-plan.
# On attend la fin de tous les processus fils avant de continuer.
# ---------------------------------------------------------------------------
run_fork() {
    log_info "=== MODE FORK : exécution parallèle par sous-processus ==="
    local pids=()
    local names=()

    # Lancement en parallèle avec l'option -f
    log_info "  [FORK] Lancement de auto_maintenance.sh -f"
    bash "${SCRIPT_MAINTENANCE}" -f &
    pids+=($!)
    names+=("auto_maintenance.sh")

    log_info "  [FORK] Lancement de data_focus.sh -f"
    bash "${SCRIPT_DATA}" -f &
    pids+=($!)
    names+=("data_focus.sh")

    log_info "  [FORK] Lancement de module_securite.sh -f"
    bash "${SCRIPT_SECURITE}" -f &
    pids+=($!)
    names+=("module_securite.sh")

    # Attente et vérification de chaque processus fils
    log_info "  [FORK] Attente de la fin de tous les processus fils..."
    local global_status=0
    for i in "${!pids[@]}"; do
        wait "${pids[$i]}"
        local exit_code=$?
        if [[ ${exit_code} -ne 0 ]]; then
            log_error "  [FORK] ✗ ${names[$i]} (PID ${pids[$i]}) a échoué (code: ${exit_code})"
            global_status="${ERR_MODULE_FAILED}"
        else
            log_info "  [FORK] ✓ ${names[$i]} (PID ${pids[$i]}) terminé avec succès."
        fi
    done

    if [[ ${global_status} -ne 0 ]]; then
        log_error "Un ou plusieurs modules ont échoué en mode fork."
        exit "${global_status}"
    fi
    log_info "=== MODE FORK : tous les processus fils terminés ==="
}

# ---------------------------------------------------------------------------
# run_thread : simulation de parallélisme via sous-processus (option -t)
# Bash ne dispose pas de threads natifs. Le parallélisme est simulé par des
# sous-processus en arrière-plan, comme pour le mode fork.
# NOTE : auto_maintenance.sh attend un argument après -t (liste de ports).
#        On lui passe "22,80,443" par défaut.
# ---------------------------------------------------------------------------
run_thread() {
    log_info "=== MODE THREAD : simulation de parallélisme en Bash ==="
    log_info "  [INFO] Bash ne supporte pas les threads natifs."
    log_info "  [INFO] Simulation via sous-processus parallèles (comportement fork)."

    local pids=()
    local names=()

    # auto_maintenance.sh -t attend une liste de ports → "22,80,443" par défaut
    log_info "  [THREAD] Lancement de auto_maintenance.sh -t \"22,80,443\""
    bash "${SCRIPT_MAINTENANCE}" -t "22,80,443" &
    pids+=($!)
    names+=("auto_maintenance.sh")

    log_info "  [THREAD] Lancement de data_focus.sh -t"
    bash "${SCRIPT_DATA}" -t &
    pids+=($!)
    names+=("data_focus.sh")

    log_info "  [THREAD] Lancement de module_securite.sh -t"
    bash "${SCRIPT_SECURITE}" -t &
    pids+=($!)
    names+=("module_securite.sh")

    # Attente et vérification de chaque processus fils
    log_info "  [THREAD] Attente de la fin de tous les sous-processus..."
    local global_status=0
    for i in "${!pids[@]}"; do
        wait "${pids[$i]}"
        local exit_code=$?
        if [[ ${exit_code} -ne 0 ]]; then
            log_error "  [THREAD] ✗ ${names[$i]} (PID ${pids[$i]}) a échoué (code: ${exit_code})"
            global_status="${ERR_MODULE_FAILED}"
        else
            log_info "  [THREAD] ✓ ${names[$i]} (PID ${pids[$i]}) terminé."
        fi
    done

    if [[ ${global_status} -ne 0 ]]; then
        log_error "Un ou plusieurs modules ont échoué en mode thread."
        exit "${global_status}"
    fi
    log_info "=== MODE THREAD : traitement terminé ==="
}

# ---------------------------------------------------------------------------
# run_subshell : exécution séquentielle dans un sous-shell isolé
# Les trois modules sont appelés avec -s dans un seul bloc sous-shell.
# Toute modification d'environnement reste locale au sous-shell.
# ---------------------------------------------------------------------------
run_subshell() {
    log_info "=== MODE SUBSHELL : exécution dans un sous-shell isolé ==="
    local global_status=0

    (
        # Ce bloc s'exécute dans un sous-shell (environnement copié mais isolé)
        log_info "  [SUBSHELL] Début du sous-shell (PID $$)"

        log_info "  [SUBSHELL] Lancement de auto_maintenance.sh -s"
        bash "${SCRIPT_MAINTENANCE}" -s
        if [[ $? -ne 0 ]]; then
            log_error "  [SUBSHELL] ✗ auto_maintenance.sh a échoué."
            exit "${ERR_MODULE_FAILED}"
        fi
        log_info "  [SUBSHELL] ✓ auto_maintenance.sh terminé."

        log_info "  [SUBSHELL] Lancement de data_focus.sh -s"
        bash "${SCRIPT_DATA}" -s
        if [[ $? -ne 0 ]]; then
            log_error "  [SUBSHELL] ✗ data_focus.sh a échoué."
            exit "${ERR_MODULE_FAILED}"
        fi
        log_info "  [SUBSHELL] ✓ data_focus.sh terminé."

        log_info "  [SUBSHELL] Lancement de module_securite.sh -s"
        bash "${SCRIPT_SECURITE}" -s
        if [[ $? -ne 0 ]]; then
            log_error "  [SUBSHELL] ✗ module_securite.sh a échoué."
            exit "${ERR_MODULE_FAILED}"
        fi
        log_info "  [SUBSHELL] ✓ module_securite.sh terminé."

        log_info "  [SUBSHELL] Tous les modules terminés dans le sous-shell."
    )

    # Récupération du code de retour du sous-shell
    local subshell_exit=$?
    if [[ ${subshell_exit} -ne 0 ]]; then
        log_error "Le sous-shell a retourné une erreur (code: ${subshell_exit})."
        global_status="${ERR_MODULE_FAILED}"
    fi

    if [[ ${global_status} -ne 0 ]]; then
        log_error "Un ou plusieurs modules ont échoué en mode subshell."
        exit "${global_status}"
    fi
    log_info "=== MODE SUBSHELL : sous-shell terminé avec succès ==="
}

# ==============================================================================
# SECTION 9 : PARSING DES OPTIONS (getopts)
# ==============================================================================

# usage_error : affiche un message d'erreur, l'aide, et quitte
# Usage : usage_error "message" <code_erreur>
usage_error() {
    local msg="$1"
    local code="${2:-${ERR_INVALID_OPTION}}"
    log_error "${msg}"
    show_help
    exit "${code}"
}

# parse_options : analyse les options de la ligne de commande avec getopts
# Options acceptées : h, f, t, s, r (sans argument) et l (avec argument)
parse_options() {
    while getopts ":hftsl:r" opt; do
        case "${opt}" in
            h)
                # Affichage de l'aide puis sortie propre
                show_help
                exit 0
                ;;
            f)
                # Activation du mode fork (exécution parallèle)
                EXEC_MODE="fork"
                ;;
            t)
                # Activation du mode thread (parallélisme simulé)
                EXEC_MODE="thread"
                ;;
            s)
                # Activation du mode subshell (environnement isolé)
                EXEC_MODE="subshell"
                ;;
            l)
                # Répertoire de log personnalisé ($OPTARG contient la valeur)
                LOG_DIR="${OPTARG}"
                ;;
            r)
                # Activation du mode restore (nécessite root)
                OPT_RESTORE=true
                ;;
            :)
                # Option connue mais sans argument obligatoire (ex: -l sans chemin)
                usage_error "L'option -${OPTARG} nécessite un argument." "${ERR_INVALID_OPTION}"
                ;;
            \?)
                # Option inconnue
                usage_error "Option invalide : -${OPTARG}" "${ERR_INVALID_OPTION}"
                ;;
        esac
    done

    # Décalage : $@ ne contient plus les options après getopts
    shift $((OPTIND - 1))

    # Récupération du paramètre positionnel obligatoire TARGET_DIR
    TARGET_DIR="$1"

    # Vérification de la présence de TARGET_DIR
    if [[ -z "${TARGET_DIR}" ]]; then
        usage_error "Paramètre obligatoire manquant : TARGET_DIR" "${ERR_MISSING_PARAM}"
    fi

    # Vérification que TARGET_DIR est un répertoire valide et accessible
    if [[ ! -d "${TARGET_DIR}" ]]; then
        usage_error "Le répertoire cible est invalide ou inaccessible : '${TARGET_DIR}'" "${ERR_INVALID_DIR}"
    fi

    # Normalisation : résolution du chemin absolu
    TARGET_DIR="$(realpath "${TARGET_DIR}")"
}

# ==============================================================================
# SECTION 10 : POINT D'ENTRÉE PRINCIPAL
# ==============================================================================

main() {
    # --- Étape 1 : Parsing des options et du paramètre obligatoire ---
    parse_options "$@"

    # --- Étape 2 : Initialisation du système de journalisation ---
    init_log

    # --- Étape 3 : Bannière de démarrage ---
    log_info "======================================================"
    log_info " ${PROG_NAME} v${VERSION} - Démarrage"
    log_info "======================================================"
    log_info "Utilisateur       : $(_username)"
    log_info "Répertoire cible  : ${TARGET_DIR}"
    log_info "Mode d'exécution  : ${EXEC_MODE}"
    log_info "Fichier de log    : ${LOG_FILE}"
    log_info "Option restore    : ${OPT_RESTORE}"
    log_info "======================================================"

    # --- Étape 4 : Traitement de l'option -r (restore) en priorité ---
    if [[ "${OPT_RESTORE}" == true ]]; then
        # La restauration nécessite les droits root
        check_admin
        restore_defaults
        log_info "Restauration effectuée. Fin du programme."
        exit 0
    fi

    # --- Étape 5 : Vérification de la présence des scripts des collègues ---
    check_dependencies

    # --- Étape 6 : Exécution selon le mode choisi ---
    log_info "Début de l'exécution en mode : ${EXEC_MODE^^}"

    case "${EXEC_MODE}" in
        normal)
            run_normal
            ;;
        fork)
            run_fork
            ;;
        thread)
            run_thread
            ;;
        subshell)
            run_subshell
            ;;
        *)
            # Mode inconnu (ne devrait pas arriver grâce à getopts)
            usage_error "Mode d'exécution inconnu : ${EXEC_MODE}" "${ERR_INVALID_OPTION}"
            ;;
    esac

    # --- Étape 7 : Fin normale du programme ---
    log_info "======================================================"
    log_info " ${PROG_NAME} v${VERSION} - Terminé avec succès"
    log_info "======================================================"
    exit 0
}

# Appel du point d'entrée en transmettant tous les arguments du script
main "$@"