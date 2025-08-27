#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/Config/dotfiles"
REPO_DIR="$HOME/Config"

echo "💾 Saving current settings into $DOTFILES_DIR"

# --- Guake ---
if command -v guake >/dev/null 2>&1; then
    echo "🖥️  Exporting Guake preferences..."
    guake --save-preferences "$DOTFILES_DIR/guake.cfg"
fi

# --- GNOME ---
if command -v dconf >/dev/null 2>&1; then
    echo "🖥️  Dumping GNOME settings..."
    dconf dump / > "$DOTFILES_DIR/gnome.cfg"
fi

# --- Git push ---
cd "$REPO_DIR"
git add .
git commit -m "Update dotfiles: $(date)" || echo "ℹ️  No changes to commit."
git push

echo "✅ Settings saved and pushed to GitHub!"

