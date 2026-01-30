#!/bin/bash
# Ralph Installation Script
# Creates a symlink to make 'ralph' available globally

set -e

# Get the directory where this script lives (ralph source)
RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default installation directory
DEFAULT_INSTALL_DIR="$HOME/.local/bin"
INSTALL_DIR="${1:-$DEFAULT_INSTALL_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Ralph Installer"
echo "==============="
echo ""

# Check if ralph.sh exists
if [ ! -f "$RALPH_DIR/ralph.sh" ]; then
  echo -e "${RED}Error: ralph.sh not found in $RALPH_DIR${NC}"
  exit 1
fi

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo "Creating directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

# Create symlink
LINK_PATH="$INSTALL_DIR/ralph"

if [ -L "$LINK_PATH" ]; then
  echo "Removing existing symlink at $LINK_PATH"
  rm "$LINK_PATH"
elif [ -f "$LINK_PATH" ]; then
  echo -e "${YELLOW}Warning: $LINK_PATH exists and is not a symlink${NC}"
  read -p "Overwrite? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
  fi
  rm "$LINK_PATH"
fi

ln -s "$RALPH_DIR/ralph.sh" "$LINK_PATH"

echo -e "${GREEN}✓ Ralph installed to $LINK_PATH${NC}"

# Install Claude Code skills
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"

echo ""
echo "Installing Claude Code skills..."

if [ -d "$CLAUDE_SKILLS_DIR" ] || mkdir -p "$CLAUDE_SKILLS_DIR"; then
  # Copy prd skill
  if [ -d "$RALPH_DIR/skills/prd" ]; then
    rm -rf "$CLAUDE_SKILLS_DIR/prd"
    cp -r "$RALPH_DIR/skills/prd" "$CLAUDE_SKILLS_DIR/"
    echo -e "${GREEN}✓ Installed skill: prd${NC}"
  fi

  # Copy ralph skill
  if [ -d "$RALPH_DIR/skills/ralph" ]; then
    rm -rf "$CLAUDE_SKILLS_DIR/ralph"
    cp -r "$RALPH_DIR/skills/ralph" "$CLAUDE_SKILLS_DIR/"
    echo -e "${GREEN}✓ Installed skill: ralph${NC}"
  fi
else
  echo -e "${YELLOW}Warning: Could not create $CLAUDE_SKILLS_DIR${NC}"
  echo "Skills were not installed. You can install them manually."
fi

echo ""

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo -e "${YELLOW}Warning: $INSTALL_DIR is not in your PATH${NC}"
  echo ""
  echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
  echo ""
  echo "Then restart your shell or run: source ~/.bashrc"
else
  echo "You can now use 'ralph' from any directory!"
fi

echo ""
echo "Usage:"
echo ""
echo "  Shell command:"
echo "    ralph --help              Show help"
echo "    ralph init                Initialize a project"
echo "    ralph --tool claude 10   Run 10 iterations with Claude Code"
echo "    ralph --tool amp 5       Run 5 iterations with Amp"
echo ""
echo "  Claude Code skills:"
echo "    /prd                      Generate a PRD document"
echo "    /ralph                    Convert PRD to prd.json"
