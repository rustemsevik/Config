#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

echo "🚀 Installing dotfiles from $DOTFILES_DIR"

# Restore Guake preferences
if command -v guake >/dev/null 2>&1; then
    echo "🖥️  Restoring Guake preferences..."
    guake --restore-preferences "$DOTFILES_DIR/guake.cfg"
else
    echo "⚠️  Guake not installed. Skipping."
fi

# Restore GNOME settings
if command -v dconf >/dev/null 2>&1; then
    echo "🖥️  Loading GNOME settings..."
    dconf load / < "$DOTFILES_DIR/gnome.cfg"
else
    echo "⚠️  'dconf' not found. Skipping GNOME settings."
fi

echo "✅ Installation complete!"
