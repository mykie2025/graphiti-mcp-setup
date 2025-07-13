#!/bin/bash

# =====================================================
# NEO4J BACKUP/RESTORE ALIASES (APOC Enhanced)
# =====================================================
# Add these to your ~/.bashrc or ~/.zshrc:
# source /path/to/neo4j_aliases.sh
# =====================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Basic aliases for Neo4j backup and restore
alias neo4j-backup="$SCRIPT_DIR/neo4j_backup_restore.sh backup"
alias neo4j-backup-quick="$SCRIPT_DIR/neo4j_backup_restore.sh backup"
alias neo4j-restore="$SCRIPT_DIR/neo4j_backup_restore.sh restore"
alias neo4j-list="$SCRIPT_DIR/neo4j_backup_restore.sh list"
alias neo4j-clean="$SCRIPT_DIR/neo4j_backup_restore.sh clean"
alias neo4j-apoc-status="$SCRIPT_DIR/neo4j_backup_restore.sh apoc-status"

# APOC-specific aliases
alias neo4j-backup-apoc="$SCRIPT_DIR/neo4j_backup_restore.sh backup"
alias neo4j-backup-apoc-repo="$SCRIPT_DIR/neo4j_backup_restore.sh backup"

# Convenience functions
neo4j-backup-repo() {
    if [ -z "$1" ]; then
        echo "Usage: neo4j-backup-repo <repository_name> [quick|apoc|apoc-repo]"
        echo "  quick     - Repository-specific backup (APOC if available)"
        echo "  apoc      - APOC full database export (Cypher + JSON + GraphML)"
        echo "  apoc-repo - APOC repository-specific export"
        return 1
    fi
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "$1" "$2"
}

neo4j-restore-repo() {
    if [ -z "$1" ]; then
        echo "Usage: neo4j-restore-repo <backup_path> [target_group_id|clear|clear-repo]"
        echo "  clear      - Clear entire database before restore"
        echo "  clear-repo - Clear only repository data before restore"
        return 1
    fi
    "$SCRIPT_DIR/neo4j_backup_restore.sh" restore "$1" "$2"
}

# APOC-specific functions
neo4j-backup-apoc-full() {
    if [ -z "$1" ]; then
        echo "Usage: neo4j-backup-apoc-full <repository_name>"
        echo "Creates full APOC backup with Cypher, JSON, and GraphML exports"
        return 1
    fi
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "$1" apoc
}

neo4j-backup-apoc-repository() {
    if [ -z "$1" ]; then
        echo "Usage: neo4j-backup-apoc-repository <repository_name>"
        echo "Creates repository-specific APOC backup"
        return 1
    fi
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "$1" apoc-repo
}

neo4j-restore-clear() {
    if [ -z "$1" ]; then
        echo "Usage: neo4j-restore-clear <backup_path>"
        echo "Restores backup after clearing entire database"
        return 1
    fi
    "$SCRIPT_DIR/neo4j_backup_restore.sh" restore "$1" clear
}

neo4j-restore-clear-repo() {
    if [ -z "$1" ]; then
        echo "Usage: neo4j-restore-clear-repo <backup_path>"
        echo "Restores backup after clearing repository data only"
        return 1
    fi
    "$SCRIPT_DIR/neo4j_backup_restore.sh" restore "$1" clear-repo
}

# Quick commands for current repository
neo4j-backup-current() {
    local repo_name=$(basename "$PWD")
    local backup_type="$1"
    
    if [ -z "$backup_type" ]; then
        backup_type="quick"
    fi
    
    echo "Backing up current repository: $repo_name (type: $backup_type)"
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "$repo_name" "$backup_type"
}

neo4j-backup-current-apoc() {
    local repo_name=$(basename "$PWD")
    echo "Creating APOC full backup for current repository: $repo_name"
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "$repo_name" apoc
}

neo4j-backup-current-apoc-repo() {
    local repo_name=$(basename "$PWD")
    echo "Creating APOC repository backup for current repository: $repo_name"
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "$repo_name" apoc-repo
}

# Graphiti-specific shortcuts
neo4j-backup-graphiti() {
    local backup_type="$1"
    if [ -z "$backup_type" ]; then
        backup_type="quick"
    fi
    echo "Backing up Graphiti repository (type: $backup_type)"
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "graphiti-repo" "$backup_type"
}

neo4j-backup-graphiti-apoc() {
    echo "Creating APOC full backup for Graphiti repository"
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "graphiti-repo" apoc
}

neo4j-backup-graphiti-apoc-repo() {
    echo "Creating APOC repository backup for Graphiti repository"
    "$SCRIPT_DIR/neo4j_backup_restore.sh" backup "graphiti-repo" apoc-repo
}

# Utility functions
neo4j-show-backups() {
    echo "=== Available Neo4j Backups ==="
    "$SCRIPT_DIR/neo4j_backup_restore.sh" list
}

neo4j-clean-old() {
    local days="$1"
    if [ -z "$days" ]; then
        days=30
    fi
    echo "Cleaning backups older than $days days..."
    "$SCRIPT_DIR/neo4j_backup_restore.sh" clean "$days"
}

neo4j-status() {
    echo "=== Neo4j Container Status ==="
    if docker ps | grep -q "graphiti-mcp-setup-neo4j-1"; then
        echo "✅ Neo4j container is running"
    else
        echo "❌ Neo4j container is not running"
        echo "Start with: docker-compose up -d"
    fi
    echo ""
    "$SCRIPT_DIR/neo4j_backup_restore.sh" apoc-status
}

# Help function
neo4j-help() {
    echo "=== Neo4j Backup/Restore Commands (APOC Enhanced) ==="
    echo ""
    echo "BASIC COMMANDS:"
    echo "  neo4j-backup <repo> [type]        - Backup repository"
    echo "  neo4j-restore <path> [options]    - Restore from backup"
    echo "  neo4j-list                        - List all backups"
    echo "  neo4j-clean [days]                - Clean old backups"
    echo "  neo4j-apoc-status                 - Show APOC plugin status"
    echo ""
    echo "BACKUP TYPES:"
    echo "  default    - Full backup (APOC if available, fallback to legacy)"
    echo "  quick      - Repository-specific backup (APOC if available)"
    echo "  apoc       - APOC full database export (Cypher + JSON + GraphML)"
    echo "  apoc-repo  - APOC repository-specific export"
    echo ""
    echo "APOC-SPECIFIC COMMANDS:"
    echo "  neo4j-backup-apoc-full <repo>     - APOC full backup"
    echo "  neo4j-backup-apoc-repository <repo> - APOC repository backup"
    echo "  neo4j-restore-clear <path>        - Restore with full database clear"
    echo "  neo4j-restore-clear-repo <path>   - Restore with repository clear"
    echo ""
    echo "CURRENT REPOSITORY SHORTCUTS:"
    echo "  neo4j-backup-current [type]       - Backup current directory repo"
    echo "  neo4j-backup-current-apoc         - APOC full backup of current repo"
    echo "  neo4j-backup-current-apoc-repo    - APOC repo backup of current repo"
    echo ""
    echo "GRAPHITI SHORTCUTS:"
    echo "  neo4j-backup-graphiti [type]      - Backup Graphiti repository"
    echo "  neo4j-backup-graphiti-apoc        - APOC full backup of Graphiti"
    echo "  neo4j-backup-graphiti-apoc-repo   - APOC repo backup of Graphiti"
    echo ""
    echo "UTILITY COMMANDS:"
    echo "  neo4j-show-backups                - Show all available backups"
    echo "  neo4j-clean-old [days]            - Clean backups older than N days"
    echo "  neo4j-status                      - Show container and APOC status"
    echo "  neo4j-help                        - Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  neo4j-backup-graphiti-apoc        - Full APOC backup of Graphiti"
    echo "  neo4j-backup-current apoc-repo    - APOC repo backup of current dir"
    echo "  neo4j-restore-clear ~/neo4j-backups/graphiti-repo_apoc_20250712_143000"
    echo "  neo4j-clean-old 7                 - Clean backups older than 7 days"
}

# Load message
echo "Neo4j backup/restore aliases loaded! (APOC Enhanced)"
echo "Available commands:"
echo "  neo4j-backup <repo> [type]"
echo "  neo4j-restore <path> [options]"
echo "  neo4j-list, neo4j-clean, neo4j-apoc-status"
echo "  neo4j-backup-current [type]"
echo "  neo4j-backup-graphiti [type]"
echo ""
echo "APOC commands:"
echo "  neo4j-backup-apoc-full <repo>"
echo "  neo4j-backup-apoc-repository <repo>"
echo "  neo4j-restore-clear <path>"
echo "  neo4j-restore-clear-repo <path>"
echo ""
echo "Type 'neo4j-help' for full command reference" 