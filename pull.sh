#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/Config/dotfiles"
ZSH_INIT="$DOTFILES_DIR/zshrc.init"
ZSHRC="$HOME/.zshrc"
REPO_DIR="$HOME/Config"

echo "🚀 Installing dotfiles from $DOTFILES_DIR"

# --- Git sync first ---
cd "$REPO_DIR"
echo "🔄 Pulling latest changes from GitHub..."
git pull --rebase

# --- Guake ---
if command -v guake >/dev/null 2>&1; then
    echo "🖥️  Restoring Guake preferences..."
    guake --restore-preferences "$DOTFILES_DIR/guake.cfg"
else
    echo "⚠️  Guake not installed. Skipping."
fi

# --- GNOME ---
if command -v dconf >/dev/null 2>&1; then
    echo "🖥️  Loading GNOME settings..."
    dconf load / < "$DOTFILES_DIR/gnome.cfg"
else
    echo "⚠️  'dconf' not found. Skipping GNOME settings."
fi

# --- Zsh ---
if [ -f "$ZSH_INIT" ]; then
    echo "🔗 Ensuring $ZSHRC sources $ZSH_INIT"
    if ! grep -Fxq "source $ZSH_INIT" "$ZSHRC" 2>/dev/null; then
        cp "$ZSHRC" "${ZSHRC}.bak" 2>/dev/null || true
        echo "source $ZSH_INIT" >> "$ZSHRC"
        echo "✅ Added source line to $ZSHRC (backup at ${ZSHRC}.bak)"
    else
        echo "ℹ️  $ZSHRC already sources $ZSH_INIT"
    fi
else
    echo "⚠️  Zsh init file not found at $ZSH_INIT"
fi

echo "✅ Installation complete!"

