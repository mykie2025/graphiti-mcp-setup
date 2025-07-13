# Graphiti MCP Setup

A comprehensive Docker-based infrastructure for running **Graphiti MCP (Memory Context Protocol)** services with Neo4j knowledge graph backend and Cursor IDE integration.

## 🚀 Overview

This repository provides a complete knowledge graph infrastructure that enables AI agents to store and retrieve episodic memories through a graph database structure. The setup includes:

- **Neo4j Database** with extensive APOC plugin support (192+ procedures)
- **Graphiti MCP Server** with OpenAI API integration
- **Cursor IDE Integration** via MCP configuration
- **Backup & Restore Scripts** for data management
- **Pre-written Cypher Queries** for graph analysis

## 📋 Prerequisites

- **Docker Desktop** installed and running
- **OpenAI API Key** (or compatible API endpoint)
- **Cursor IDE** (for MCP integration)
- **macOS/Linux** environment (tested on darwin 25.0.0)

## ⚡ Quick Start

### 1. Clone and Setup Environment

```bash
git clone <repository-url>
cd graphiti-mcp-setup

# Copy environment template and configure
cp .env.example .env
# Edit .env with your OpenAI API key
```

### 2. Configure Environment Variables

Edit `.env` file with your settings:

```bash
# OpenAI Configuration (Required)
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_API_BASE=https://api.openai.com/v1
DEFAULT_LLM_MODEL=gpt-4o-mini

# Neo4j Configuration
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=password
NEO4J_PORT=7687
NEO4J_DATABASE=neo4j

# Graphiti MCP Server Configuration
SEMAPHORE_LIMIT=20
MAX_REFLEXION_ITERATIONS=0
```

### 3. Start Services

```bash
# Start all services
docker compose up -d

# Check service health
docker ps
```

### 4. Verify Setup

- **Neo4j Browser**: http://localhost:7474 (neo4j/password)
- **Graphiti API**: http://localhost:8000
- **Health Check**: http://localhost:8000/health

## 🏗️ Architecture

### Services

| Service | Port | Description |
|---------|------|-------------|
| **Neo4j** | 7474 (HTTP), 7687 (Bolt) | Graph database with APOC plugins |
| **Graphiti** | 8000 | MCP server with OpenAI integration |
| **MCP Server** | - | Knowledge graph MCP for Cursor IDE |

### Data Flow

```
Cursor IDE → MCP Server → Graphiti Service → Neo4j Database
```

## 📝 Cursor IDE Integration

### MCP Configuration

Add to your `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "graphiti-memory": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "--network", "host",
        "-e", "NEO4J_URI=bolt://localhost:7687",
        "-e", "NEO4J_USER=neo4j",
        "-e", "NEO4J_PASSWORD=password",
        "zepai/knowledge-graph-mcp"
      ],
      "env": {}
    }
  }
}
```

### Available MCP Tools

- `search_memory_nodes` - Find entities by meaning
- `search_memory_facts` - Find relationships and facts
- `add_memory` - Store new information as episodes
- `get_episodes` - Retrieve recent episodes
- `delete_entity_edge` - Remove specific relationships
- `delete_episode` - Remove episodes

## 🗃️ Data Management

### Backup & Restore

All backups are stored locally in the `./backups/` folder for portability and easy management. Use the provided scripts for data management:

```bash
# Create backup (stored in ./backups/ folder)
./neo4j_backup_restore.sh backup graphiti-graph apoc

# Restore from backup (from ./backups/ folder)
./neo4j_backup_restore.sh restore ./backups/graphiti-graph_apoc_20250713_100136

# List available backups
./neo4j_backup_restore.sh list
```

### Useful Aliases

Source the aliases for convenient database operations:

```bash
source neo4j_aliases.sh

# Now you can use:
neo4j-status      # Check database status
neo4j-backup      # Quick backup (saves to ./backups/)
neo4j-restore     # Interactive restore (from ./backups/)
```

## 📊 Database Queries

### Pre-written Cypher Queries

The repository includes 30 pre-written Cypher queries in `neo4j_queries.cypher`:

**Categories:**
- **Schema Overview** (3 queries) - Database structure
- **Content Exploration** (4 queries) - Browse entities and episodes
- **Relationship Analysis** (3 queries) - Entity connections
- **Repository Insights** (4 queries) - Project-specific analysis
- **Graph Visualization** (3 queries) - Network views
- **Search & Analysis** (4 queries) - Find specific data
- **Advanced Analysis** (5 queries) - Complex analytics
- **Maintenance** (4 queries) - Database health

### Example Queries

```cypher
-- View all entities
MATCH (n:Entity) 
WHERE n.group_id = 'default'
RETURN n.name, n.summary 
ORDER BY n.created_at DESC;

-- Explore relationships
MATCH (a:Entity)-[r:RELATES_TO]->(b:Entity)
WHERE a.group_id = 'default'
RETURN a.name as Source, b.name as Target
LIMIT 10;

-- Episode timeline
MATCH (n:Episodic) 
WHERE n.group_id = 'default'
RETURN n.name, n.created_at 
ORDER BY n.created_at DESC;
```

## 🔧 Development

### Database Schema

Current schema structure:
- **Labels**: `Entity`, `Episodic`
- **Relationships**: `RELATES_TO`, `MENTIONS`
- **Group ID**: `default`

### APOC Procedures

The setup includes 192+ APOC procedures for:
- Data export/import
- Graph algorithms
- UUID generation
- Triggers and TTL
- Performance optimization

### Environment Details

- **OS**: macOS darwin 25.0.0
- **Shell**: /bin/zsh
- **Architecture**: Multi-arch support (arm64, x86_64)
- **Privacy**: Telemetry disabled by default

## 🛠️ Troubleshooting

### Common Issues

**Port Conflicts:**
```bash
# Check port usage
lsof -i :7687
lsof -i :7474

# Kill conflicting processes
kill -9 <PID>
```

**Container Issues:**
```bash
# View logs
docker compose logs neo4j
docker compose logs graph

# Restart services
docker compose restart
```

**Database Connection:**
```bash
# Test Neo4j connection
docker exec graphiti-mcp-setup-neo4j-1 cypher-shell -u neo4j -p password "MATCH (n) RETURN count(n);"
```

### Health Checks

```bash
# Service status
docker compose ps

# API health
curl http://localhost:8000/health

# Database status
source neo4j_aliases.sh && neo4j_status
```

## 📚 Usage Examples

### Basic Knowledge Graph Operations

```bash
# Start interactive session in Cursor IDE
# Use MCP tools to:
# 1. Search existing knowledge: search_memory_nodes
# 2. Add new information: add_memory
# 3. Explore relationships: search_memory_facts
```

### Advanced Analytics

Use the provided Cypher queries for:
- Entity relationship mapping
- Timeline analysis
- Graph visualization
- Performance monitoring

## 🔒 Security

- Neo4j credentials: `neo4j/password`
- OpenAI API key stored in `.env`
- Host network access for container communication
- Data persistence through Docker volumes

## 📞 Support

For issues and questions:
1. Check Docker service logs
2. Verify environment configuration
3. Test database connectivity
4. Review MCP server status

## 📈 Recent Updates

- **Container Names**: Updated all scripts to use correct Docker container names (`graphiti-mcp-setup-neo4j-1`, `graphiti-mcp-setup-graph-1`)
- **Local Backups**: Changed backup directory from `~/neo4j-backups` to `./backups/` for better portability
- **Improved Scripts**: Fixed backup/restore operations and alias commands for seamless functionality

## 📄 License

[Add your license information here]

---

**Built with:** Docker • Neo4j • Graphiti • OpenAI • Cursor IDE 