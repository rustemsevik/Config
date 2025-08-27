#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

echo "💾 Saving current settings into $DOTFILES_DIR"

# Save Guake preferences
if command -v guake >/dev/null 2>&1; then
    echo "🖥️  Exporting Guake preferences..."
    guake --save-preferences "$DOTFILES_DIR/guake.cfg"
fi

# Save GNOME settings
if command -v dconf >/dev/null 2>&1; then
    echo "🖥️  Dumping GNOME settings..."
    dconf dump / > "$DOTFILES_DIR/gnome.cfg"
fi

# Push to GitHub
cd "$DOTFILES_DIR"
git add .
git commit -m "Update dotfiles: $(date)"
git push

echo "✅ Settings saved and pushed to GitHub!"
