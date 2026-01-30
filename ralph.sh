#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ralph [--tool amp|claude] [max_iterations]
#        ralph init
#        ralph --help | --version

set -e

VERSION="1.0.0"

# Installation directory (where templates live)
RALPH_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Project directory (current working directory)
PROJECT_DIR="$(pwd)"

# Templates come from installation
CLAUDE_TEMPLATE="$RALPH_HOME/CLAUDE.md"
AMP_TEMPLATE="$RALPH_HOME/prompt.md"

# Working files stay in project
PRD_FILE="$PROJECT_DIR/prd.json"
PROGRESS_FILE="$PROJECT_DIR/progress.txt"
RALPH_STATE_DIR="$PROJECT_DIR/.ralph"
ARCHIVE_DIR="$RALPH_STATE_DIR/archive"
LAST_BRANCH_FILE="$RALPH_STATE_DIR/.last-branch"

# Help function
show_help() {
  cat << EOF
Ralph - Autonomous AI agent loop for implementing PRDs

USAGE:
    ralph [OPTIONS] [max_iterations]
    ralph init
    ralph --help | --version

COMMANDS:
    init              Initialize a project for Ralph (creates .ralph/ directory)
    [max_iterations]  Run Ralph loop (default: 10 iterations)

OPTIONS:
    --tool <amp|claude>   Select AI coding tool (default: amp)
    --help, -h            Show this help message
    --version, -v         Show version information

EXAMPLES:
    ralph --tool claude 10    Run 10 iterations with Claude Code
    ralph --tool amp 5        Run 5 iterations with Amp
    ralph init                Set up project for Ralph

FILES:
    Templates (in RALPH_HOME=$RALPH_HOME):
      CLAUDE.md             Prompt template for Claude Code
      prompt.md             Prompt template for Amp

    Project files (in current directory):
      prd.json              User stories with passes status (required)
      progress.txt          Append-only learnings log (auto-created)
      .ralph/               State directory (auto-created)
        archive/            Archived runs by date/branch
        .last-branch        Branch tracking state

For more information, visit: https://github.com/snarktank/ralph
EOF
}

# Version function
show_version() {
  echo "ralph version $VERSION"
}

# Init function
init_project() {
  echo "Initializing Ralph in $PROJECT_DIR..."

  # Create .ralph directory
  mkdir -p "$RALPH_STATE_DIR"
  mkdir -p "$ARCHIVE_DIR"

  # Create .gitignore for .ralph if it doesn't exist
  if [ ! -f "$RALPH_STATE_DIR/.gitignore" ]; then
    cat > "$RALPH_STATE_DIR/.gitignore" << 'EOF'
# Ralph state files (project-specific, not shared)
.last-branch
EOF
  fi

  echo "Created .ralph/ directory structure"

  # Check if prd.json exists
  if [ ! -f "$PRD_FILE" ]; then
    echo ""
    echo "Note: No prd.json found in $PROJECT_DIR"
    echo "Create a prd.json file to define your user stories."
    echo "See: $RALPH_HOME/prd.json.example for format reference"
  else
    echo "Found existing prd.json"
  fi

  echo ""
  echo "Ralph initialized! Run 'ralph --tool claude' or 'ralph --tool amp' to start."
}

# Parse arguments
TOOL="amp"  # Default to amp for backwards compatibility
MAX_ITERATIONS=10
COMMAND=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      show_help
      exit 0
      ;;
    --version|-v)
      show_version
      exit 0
      ;;
    init)
      COMMAND="init"
      shift
      ;;
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Handle init command
if [[ "$COMMAND" == "init" ]]; then
  init_project
  exit 0
fi

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp' or 'claude'."
  echo "Run 'ralph --help' for usage information."
  exit 1
fi

# Check that required files exist
if [ ! -f "$PRD_FILE" ]; then
  echo "Error: No prd.json found in $PROJECT_DIR"
  echo ""
  echo "Ralph requires a prd.json file in your project directory."
  echo "Run 'ralph init' to set up the project, then create your prd.json."
  echo "See: $RALPH_HOME/prd.json.example for format reference"
  exit 1
fi

# Ensure .ralph state directory exists
if [ ! -d "$RALPH_STATE_DIR" ]; then
  mkdir -p "$RALPH_STATE_DIR"
  mkdir -p "$ARCHIVE_DIR"
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$AMP_TEMPLATE" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    OUTPUT=$(claude --dangerously-skip-permissions --print --verbose < "$CLAUDE_TEMPLATE" 2>&1 | tee /dev/stderr) || true
  fi
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
