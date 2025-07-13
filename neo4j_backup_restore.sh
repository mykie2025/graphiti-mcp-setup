#!/bin/bash

# =====================================================
# NEO4J BACKUP AND RESTORE CLI COMMANDS
# =====================================================
# For Neo4j Community Edition with APOC Plugin
# Supports multiple repositories with separate backups
# Enhanced with APOC export/import capabilities
# =====================================================

# Configuration
BACKUP_DIR="./backups"
CONTAINER_NAME="graphiti-mcp-setup-neo4j-1"
VOLUME_NAME="graphiti_neo4j_data"
NEO4J_USER="neo4j"
NEO4J_PASSWORD="password"
APOC_IMPORT_DIR="/var/lib/neo4j/import"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if container is running
check_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "Neo4j container '$CONTAINER_NAME' is not running!"
        echo "Start it with: docker-compose up -d"
        exit 1
    fi
}

# Check if APOC is available
check_apoc() {
    local apoc_check=$(docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.help('export') YIELD name RETURN count(name) as apoc_count" 2>/dev/null || echo "")
    
    if [ -n "$apoc_check" ] && [[ "$apoc_check" == *"apoc_count"* ]]; then
        print_success "APOC plugin is available"
        return 0
    else
        print_warning "APOC plugin not available, falling back to basic methods"
        return 1
    fi
}

# Create backup directory structure
setup_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    print_success "Backup directory created at: $BACKUP_DIR"
}

# =====================================================
# APOC BACKUP FUNCTIONS
# =====================================================

# APOC-based full backup
backup_apoc_full() {
    local repo_name="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/${repo_name}_apoc_${timestamp}"
    
    print_header "APOC FULL BACKUP: $repo_name"
    
    check_container
    if ! check_apoc; then
        print_error "APOC not available for full backup"
        return 1
    fi
    
    setup_backup_dir
    mkdir -p "$backup_path"
    
    # Export everything using APOC
    print_warning "Exporting full database using APOC..."
    
    # Export all data as Cypher statements
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.export.cypher.all('${repo_name}_full.cypher', {format: 'cypher-shell', useOptimizations: {type: 'UNWIND_BATCH', unwindBatchSize: 20}})"
    
    # Export as JSON for easier parsing
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.export.json.all('${repo_name}_full.json', {useTypes: true})"
    
    # Export as GraphML for visualization tools
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.export.graphml.all('${repo_name}_full.graphml', {})"
    
    # Copy exported files from container to backup directory
    docker cp "$CONTAINER_NAME:$APOC_IMPORT_DIR/${repo_name}_full.cypher" "$backup_path/"
    docker cp "$CONTAINER_NAME:$APOC_IMPORT_DIR/${repo_name}_full.json" "$backup_path/"
    docker cp "$CONTAINER_NAME:$APOC_IMPORT_DIR/${repo_name}_full.graphml" "$backup_path/"
    
    # Clean up files in container
    docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/${repo_name}_full.cypher"
    docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/${repo_name}_full.json"
    docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/${repo_name}_full.graphml"
    
    # Create metadata file
    cat > "$backup_path/backup_metadata.json" << EOF
{
    "repository": "$repo_name",
    "timestamp": "$timestamp",
    "backup_date": "$(date)",
    "backup_type": "apoc_full",
    "container_name": "$CONTAINER_NAME",
    "volume_name": "$VOLUME_NAME",
    "neo4j_version": "$(docker exec $CONTAINER_NAME neo4j version 2>/dev/null || echo 'unknown')",
    "apoc_version": "$(docker exec $CONTAINER_NAME cypher-shell -u $NEO4J_USER -p $NEO4J_PASSWORD 'CALL apoc.help(\"version\") YIELD name RETURN \"available\" as status' 2>/dev/null | grep -o 'available' || echo 'unknown')",
    "backup_methods": ["apoc_cypher", "apoc_json", "apoc_graphml"],
    "files": [
        "${repo_name}_full.cypher",
        "${repo_name}_full.json", 
        "${repo_name}_full.graphml"
    ]
}
EOF
    
    print_success "APOC full backup completed: $backup_path"
    echo "Backup contains:"
    echo "  - ${repo_name}_full.cypher (Cypher statements)"
    echo "  - ${repo_name}_full.json (JSON export)"
    echo "  - ${repo_name}_full.graphml (GraphML for visualization)"
    echo "  - backup_metadata.json (metadata)"
}

# APOC-based repository-specific backup
backup_apoc_repo() {
    local repo_name="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/${repo_name}_apoc_repo_${timestamp}"
    
    print_header "APOC REPOSITORY BACKUP: $repo_name"
    
    check_container
    if ! check_apoc; then
        print_error "APOC not available for repository backup"
        return 1
    fi
    
    setup_backup_dir
    mkdir -p "$backup_path"
    
    # Export repository-specific data using APOC
    print_warning "Exporting repository-specific data using APOC..."
    
    # Export nodes for specific group_id
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.export.cypher.query('MATCH (n) WHERE n.group_id = \"$repo_name\" RETURN n', '${repo_name}_nodes.cypher', {format: 'cypher-shell'})"
    
    # Export relationships for specific group_id
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.export.cypher.query('MATCH (a)-[r]->(b) WHERE a.group_id = \"$repo_name\" OR b.group_id = \"$repo_name\" RETURN a, r, b', '${repo_name}_relationships.cypher', {format: 'cypher-shell'})"
    
    # Export as JSON for specific group_id
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "CALL apoc.export.json.query('MATCH (n) WHERE n.group_id = \"$repo_name\" OPTIONAL MATCH (n)-[r]-(m) WHERE m.group_id = \"$repo_name\" RETURN n, r, m', '${repo_name}_data.json', {useTypes: true})"
    
    # Copy exported files from container to backup directory
    docker cp "$CONTAINER_NAME:$APOC_IMPORT_DIR/${repo_name}_nodes.cypher" "$backup_path/"
    docker cp "$CONTAINER_NAME:$APOC_IMPORT_DIR/${repo_name}_relationships.cypher" "$backup_path/"
    docker cp "$CONTAINER_NAME:$APOC_IMPORT_DIR/${repo_name}_data.json" "$backup_path/"
    
    # Clean up files in container
    docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/${repo_name}_nodes.cypher"
    docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/${repo_name}_relationships.cypher"
    docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/${repo_name}_data.json"
    
    # Create metadata file
    cat > "$backup_path/backup_metadata.json" << EOF
{
    "repository": "$repo_name",
    "timestamp": "$timestamp",
    "backup_date": "$(date)",
    "backup_type": "apoc_repository",
    "group_id": "$repo_name",
    "backup_methods": ["apoc_query_export"],
    "files": [
        "${repo_name}_nodes.cypher",
        "${repo_name}_relationships.cypher",
        "${repo_name}_data.json"
    ]
}
EOF
    
    print_success "APOC repository backup completed: $backup_path"
    echo "Backup contains:"
    echo "  - ${repo_name}_nodes.cypher (Repository nodes)"
    echo "  - ${repo_name}_relationships.cypher (Repository relationships)"
    echo "  - ${repo_name}_data.json (Repository data as JSON)"
    echo "  - backup_metadata.json (metadata)"
}

# =====================================================
# LEGACY BACKUP FUNCTIONS (Fallback)
# =====================================================

# Full database backup (Community Edition approach)
backup_full() {
    local repo_name="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/${repo_name}_${timestamp}"
    
    print_header "BACKING UP REPOSITORY: $repo_name"
    
    check_container
    setup_backup_dir
    
    # Try APOC first, fallback to legacy methods
    if check_apoc; then
        backup_apoc_full "$repo_name"
        return $?
    fi
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Method 1: Export using cypher-shell (Data Export)
    print_warning "Exporting data using Cypher queries..."
    
    # Export all nodes
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "MATCH (n) RETURN n" > "$backup_path/nodes_export.cypher" 2>/dev/null
    
    # Export all relationships
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "MATCH (a)-[r]->(b) RETURN a, r, b" > "$backup_path/relationships_export.cypher" 2>/dev/null
    
    # Method 2: Database files backup (Volume copy)
    print_warning "Backing up database files..."
    
    # Stop Neo4j temporarily for consistent backup
    docker exec "$CONTAINER_NAME" neo4j stop 2>/dev/null || true
    sleep 2
    
    # Copy database files
    docker run --rm \
        -v "$VOLUME_NAME":/source \
        -v "$backup_path":/backup \
        alpine:latest \
        cp -r /source /backup/database_files
    
    # Restart Neo4j
    docker exec "$CONTAINER_NAME" neo4j start 2>/dev/null || true
    sleep 5
    
    # Create metadata file
    cat > "$backup_path/backup_metadata.json" << EOF
{
    "repository": "$repo_name",
    "timestamp": "$timestamp",
    "backup_date": "$(date)",
    "backup_type": "legacy_full",
    "container_name": "$CONTAINER_NAME",
    "volume_name": "$VOLUME_NAME",
    "neo4j_version": "$(docker exec $CONTAINER_NAME neo4j version 2>/dev/null || echo 'unknown')",
    "backup_methods": ["cypher_export", "volume_copy"]
}
EOF
    
    print_success "Legacy backup completed: $backup_path"
    echo "Backup contains:"
    echo "  - nodes_export.cypher"
    echo "  - relationships_export.cypher"
    echo "  - database_files/ (full database)"
    echo "  - backup_metadata.json"
}

# Quick backup using Cypher export only
backup_quick() {
    local repo_name="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/${repo_name}_quick_${timestamp}"
    
    print_header "QUICK BACKUP: $repo_name"
    
    check_container
    setup_backup_dir
    
    # Try APOC repository backup first
    if check_apoc; then
        backup_apoc_repo "$repo_name"
        return $?
    fi
    
    # Fallback to legacy quick backup
    mkdir -p "$backup_path"
    
    # Export specific group data
    print_warning "Exporting repository-specific data..."
    
    # Export episodes for specific repo
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "MATCH (n:Episodic) WHERE n.group_id = '$repo_name' RETURN n" \
        > "$backup_path/episodes_${repo_name}.cypher"
    
    # Export entities for specific repo
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "MATCH (n:Entity) WHERE n.group_id = '$repo_name' RETURN n" \
        > "$backup_path/entities_${repo_name}.cypher"
    
    # Export relationships for specific repo
    docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
        "MATCH (a)-[r]->(b) WHERE a.group_id = '$repo_name' RETURN a, r, b" \
        > "$backup_path/relationships_${repo_name}.cypher"
    
    # Create metadata
    cat > "$backup_path/backup_metadata.json" << EOF
{
    "repository": "$repo_name",
    "timestamp": "$timestamp",
    "backup_date": "$(date)",
    "backup_type": "legacy_quick",
    "group_id": "$repo_name"
}
EOF
    
    print_success "Legacy quick backup completed: $backup_path"
}

# =====================================================
# APOC RESTORE FUNCTIONS
# =====================================================

# Restore from APOC backup
restore_apoc() {
    local backup_path="$1"
    local clear_existing="$2"
    
    if [ ! -d "$backup_path" ]; then
        print_error "Backup path does not exist: $backup_path"
        exit 1
    fi
    
    print_header "RESTORING FROM APOC BACKUP: $backup_path"
    
    check_container
    if ! check_apoc; then
        print_error "APOC not available for restore"
        return 1
    fi
    
    # Read metadata
    local repo_name="unknown"
    local backup_type="unknown"
    if [ -f "$backup_path/backup_metadata.json" ]; then
        repo_name=$(grep '"repository"' "$backup_path/backup_metadata.json" | cut -d'"' -f4)
        backup_type=$(grep '"backup_type"' "$backup_path/backup_metadata.json" | cut -d'"' -f4)
        print_warning "Restoring repository: $repo_name (type: $backup_type)"
    fi
    
    # Clear existing data if requested
    if [ "$clear_existing" = "clear" ]; then
        print_warning "Clearing existing database..."
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "MATCH (n) DETACH DELETE n"
    elif [ "$clear_existing" = "clear-repo" ] && [ "$repo_name" != "unknown" ]; then
        print_warning "Clearing existing data for repository: $repo_name"
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "MATCH (n) WHERE n.group_id = '$repo_name' DETACH DELETE n"
    fi
    
    # Find and restore Cypher file
    local cypher_file=$(find "$backup_path" -name "*.cypher" -type f | head -1)
    if [ -n "$cypher_file" ]; then
        print_warning "Restoring from Cypher file: $(basename "$cypher_file")"
        
        # Copy file to container import directory
        docker cp "$cypher_file" "$CONTAINER_NAME:$APOC_IMPORT_DIR/"
        local filename=$(basename "$cypher_file")
        
        # Import using APOC
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "CALL apoc.cypher.runFile('$filename')"
        
        # Clean up
        docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/$filename"
        
        print_success "Cypher file restored successfully"
    fi
    
    # Find and restore JSON file
    local json_file=$(find "$backup_path" -name "*.json" -not -name "backup_metadata.json" -type f | head -1)
    if [ -n "$json_file" ]; then
        print_warning "Restoring from JSON file: $(basename "$json_file")"
        
        # Copy file to container import directory
        docker cp "$json_file" "$CONTAINER_NAME:$APOC_IMPORT_DIR/"
        local filename=$(basename "$json_file")
        
        # Import using APOC
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "CALL apoc.import.json('$filename')"
        
        # Clean up
        docker exec "$CONTAINER_NAME" rm -f "$APOC_IMPORT_DIR/$filename"
        
        print_success "JSON file restored successfully"
    fi
    
    print_success "APOC restore completed"
}

# =====================================================
# LEGACY RESTORE FUNCTIONS
# =====================================================

# Restore from full backup
restore_full() {
    local backup_path="$1"
    
    if [ ! -d "$backup_path" ]; then
        print_error "Backup path does not exist: $backup_path"
        exit 1
    fi
    
    print_header "RESTORING FROM: $backup_path"
    
    check_container
    
    # Check if this is an APOC backup
    if [ -f "$backup_path/backup_metadata.json" ]; then
        local backup_type=$(grep '"backup_type"' "$backup_path/backup_metadata.json" | cut -d'"' -f4)
        if [[ "$backup_type" == *"apoc"* ]]; then
            restore_apoc "$backup_path" "clear"
            return $?
        fi
    fi
    
    # Read metadata
    if [ -f "$backup_path/backup_metadata.json" ]; then
        local repo_name=$(grep '"repository"' "$backup_path/backup_metadata.json" | cut -d'"' -f4)
        print_warning "Restoring repository: $repo_name"
    fi
    
    # Method 1: Restore database files (requires container restart)
    if [ -d "$backup_path/database_files" ]; then
        print_warning "Restoring database files..."
        
        # Stop Neo4j
        docker exec "$CONTAINER_NAME" neo4j stop 2>/dev/null || true
        sleep 2
        
        # Clear existing data
        docker run --rm \
            -v "$VOLUME_NAME":/target \
            -v "$backup_path":/backup \
            alpine:latest \
            sh -c "rm -rf /target/* && cp -r /backup/database_files/source/* /target/"
        
        # Restart Neo4j
        docker exec "$CONTAINER_NAME" neo4j start 2>/dev/null || true
        sleep 10
        
        print_success "Database files restored successfully"
    fi
    
    # Method 2: Import using Cypher (if database files restore failed)
    if [ -f "$backup_path/nodes_export.cypher" ]; then
        print_warning "Importing nodes and relationships..."
        print_warning "Manual import required for legacy Cypher exports"
    fi
}

# Restore specific repository data
restore_repo() {
    local backup_path="$1"
    local target_group_id="$2"
    
    if [ ! -d "$backup_path" ]; then
        print_error "Backup path does not exist: $backup_path"
        exit 1
    fi
    
    print_header "RESTORING REPOSITORY DATA"
    
    check_container
    
    # Check if this is an APOC backup
    if [ -f "$backup_path/backup_metadata.json" ]; then
        local backup_type=$(grep '"backup_type"' "$backup_path/backup_metadata.json" | cut -d'"' -f4)
        if [[ "$backup_type" == *"apoc"* ]]; then
            restore_apoc "$backup_path" "clear-repo"
            return $?
        fi
    fi
    
    # Clear existing data for this group_id
    if [ -n "$target_group_id" ]; then
        print_warning "Clearing existing data for group_id: $target_group_id"
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "MATCH (n) WHERE n.group_id = '$target_group_id' DETACH DELETE n"
    fi
    
    print_warning "Repository-specific restore requires manual Cypher import"
    print_warning "Use the exported .cypher files in: $backup_path"
}

# =====================================================
# UTILITY FUNCTIONS
# =====================================================

# List all backups
list_backups() {
    print_header "AVAILABLE BACKUPS"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "No backups found. Backup directory doesn't exist."
        return
    fi
    
    for backup in "$BACKUP_DIR"/*; do
        if [ -d "$backup" ]; then
            local backup_name=$(basename "$backup")
            if [ -f "$backup/backup_metadata.json" ]; then
                local repo=$(grep '"repository"' "$backup/backup_metadata.json" | cut -d'"' -f4 2>/dev/null || echo "unknown")
                local date=$(grep '"backup_date"' "$backup/backup_metadata.json" | cut -d'"' -f4 2>/dev/null || echo "unknown")
                local backup_type=$(grep '"backup_type"' "$backup/backup_metadata.json" | cut -d'"' -f4 2>/dev/null || echo "unknown")
                echo -e "${GREEN}$backup_name${NC}"
                echo "  Repository: $repo"
                echo "  Type: $backup_type"
                echo "  Date: $date"
                echo "  Path: $backup"
                echo ""
            else
                echo -e "${YELLOW}$backup_name${NC} (no metadata)"
            fi
        fi
    done
}

# Clean old backups
clean_old_backups() {
    local days="$1"
    if [ -z "$days" ]; then
        days=30
    fi
    
    print_header "CLEANING BACKUPS OLDER THAN $days DAYS"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "No backup directory found."
        return
    fi
    
    find "$BACKUP_DIR" -type d -name "*_*" -mtime +$days -exec rm -rf {} \; 2>/dev/null
    print_success "Old backups cleaned"
}

# Show APOC status and available procedures
show_apoc_status() {
    print_header "APOC STATUS"
    
    check_container
    
    if check_apoc; then
        echo -e "${GREEN}APOC Plugin Status: AVAILABLE${NC}"
        echo ""
        echo "Available APOC export procedures:"
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "CALL apoc.help('export') YIELD name, text WHERE name CONTAINS 'export' RETURN name, text LIMIT 10"
        echo ""
        echo "Available APOC import procedures:"
        docker exec "$CONTAINER_NAME" cypher-shell -u "$NEO4J_USER" -p "$NEO4J_PASSWORD" \
            "CALL apoc.help('import') YIELD name, text WHERE name CONTAINS 'import' RETURN name, text LIMIT 10"
    else
        echo -e "${RED}APOC Plugin Status: NOT AVAILABLE${NC}"
        echo "Install APOC plugin for enhanced backup/restore capabilities"
    fi
}

# =====================================================
# MAIN SCRIPT
# =====================================================

case "$1" in
    "backup")
        if [ -z "$2" ]; then
            print_error "Usage: $0 backup <repository_name> [quick|apoc|apoc-repo]"
            exit 1
        fi
        case "$3" in
            "quick")
                backup_quick "$2"
                ;;
            "apoc")
                backup_apoc_full "$2"
                ;;
            "apoc-repo")
                backup_apoc_repo "$2"
                ;;
            *)
                backup_full "$2"
                ;;
        esac
        ;;
    "restore")
        if [ -z "$2" ]; then
            print_error "Usage: $0 restore <backup_path> [target_group_id|clear|clear-repo]"
            exit 1
        fi
        if [ "$3" = "clear" ] || [ "$3" = "clear-repo" ]; then
            restore_apoc "$2" "$3"
        elif [ -n "$3" ]; then
            restore_repo "$2" "$3"
        else
            restore_full "$2"
        fi
        ;;
    "list")
        list_backups
        ;;
    "clean")
        clean_old_backups "$2"
        ;;
    "apoc-status")
        show_apoc_status
        ;;
    *)
        print_header "NEO4J BACKUP AND RESTORE UTILITY (APOC Enhanced)"
        echo "Usage:"
        echo "  $0 backup <repo_name> [quick|apoc|apoc-repo]  - Backup repository data"
        echo "  $0 restore <backup_path> [group|clear]        - Restore from backup"
        echo "  $0 list                                       - List all backups"
        echo "  $0 clean [days]                               - Clean old backups (default: 30 days)"
        echo "  $0 apoc-status                                - Show APOC plugin status"
        echo ""
        echo "Backup Types:"
        echo "  default    - Full backup (APOC if available, fallback to legacy)"
        echo "  quick      - Repository-specific backup (APOC if available)"
        echo "  apoc       - APOC full database export (Cypher + JSON + GraphML)"
        echo "  apoc-repo  - APOC repository-specific export"
        echo ""
        echo "Restore Options:"
        echo "  clear      - Clear entire database before restore"
        echo "  clear-repo - Clear only repository data before restore"
        echo ""
        echo "Examples:"
        echo "  $0 backup graphiti-repo apoc          - APOC full backup"
        echo "  $0 backup graphiti-repo apoc-repo     - APOC repository backup"
        echo "  $0 restore ./backups/graphiti-repo_apoc_20250712_143000"
        echo "  $0 restore ./backups/backup_path clear"
        echo "  $0 apoc-status"
        echo ""
        echo "Backup location: $BACKUP_DIR"
        ;;
esac 