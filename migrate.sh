#!/bin/bash
# MacBook Migration Script
# Usage: ./migrate.sh backup                    (creates zip in ~/Desktop)
# Usage: ./migrate.sh restore /path/to/backup.zip   (restores from zip)

set -e

if [ "$1" = "backup" ]; then
    echo "🔄 Backing up current laptop..."
    
    BACKUP_DIR="/tmp/migration-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"

    # Auto-detect user info from git
    USER_NAME=$(git config --global user.name 2>/dev/null || echo "")
    USER_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -z "$USER_NAME" ] || [ -z "$USER_EMAIL" ]; then
        echo "⚠️  Git not configured. Please enter your details:"
        [ -z "$USER_NAME" ] && read -p "Your full name: " USER_NAME
        [ -z "$USER_EMAIL" ] && read -p "Your email: " USER_EMAIL
    else
        echo "✅ Using Git config: $USER_NAME <$USER_EMAIL>"
    fi
    
    # Create config file for restore
    cat > "$BACKUP_DIR/user-config.txt" << EOF
USER_NAME=$USER_NAME
USER_EMAIL=$USER_EMAIL
EOF

    # Generate Brewfile
    brew bundle dump --global --force --describe
    cp ~/.Brewfile "$BACKUP_DIR/"

    # Copy important dotfiles and settings
    cp ~/.zshrc "$BACKUP_DIR/" 2>/dev/null || echo "No .zshrc found"
    cp ~/.gitconfig "$BACKUP_DIR/" 2>/dev/null || echo "No .gitconfig found" 
    cp ~/.ssh/config "$BACKUP_DIR/" 2>/dev/null || echo "No SSH config found"
    
    # Backup Cursor settings (if exists)
    if [ -d "$HOME/Library/Application Support/Cursor" ]; then
        cp -R "$HOME/Library/Application Support/Cursor" "$BACKUP_DIR/cursor-settings/"
        echo "✅ Cursor settings backed up"
    else
        echo "⚠️  Cursor settings folder not found"
    fi

    # List all SSH keys
    ls -la ~/.ssh/ > "$BACKUP_DIR/ssh-keys-list.txt"

    # Copy SSH keys
    cp -R ~/.ssh "$BACKUP_DIR/ssh-folder/"

    # Clean and copy Projects folder
    echo "Cleaning node_modules from Projects..."
    find ~/Projects -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
    cp -R ~/Projects "$BACKUP_DIR/projects/" 2>/dev/null || echo "No ~/Projects folder found"

    # Check applications
    ls /Applications > "$BACKUP_DIR/all-applications.txt"
    ls ~/Applications > "$BACKUP_DIR/user-applications.txt" 2>/dev/null || true
    
    # Create app diff
    echo "=== Apps in /Applications ===" > "$BACKUP_DIR/app-analysis.txt"
    cat "$BACKUP_DIR/all-applications.txt" >> "$BACKUP_DIR/app-analysis.txt"
    echo "" >> "$BACKUP_DIR/app-analysis.txt"
    echo "=== Apps in ~/Applications ===" >> "$BACKUP_DIR/app-analysis.txt"
    cat "$BACKUP_DIR/user-applications.txt" >> "$BACKUP_DIR/app-analysis.txt"
    echo "" >> "$BACKUP_DIR/app-analysis.txt"
    echo "=== Homebrew Casks ===" >> "$BACKUP_DIR/app-analysis.txt"
    brew list --cask >> "$BACKUP_DIR/app-analysis.txt" 2>/dev/null || echo "No casks installed" >> "$BACKUP_DIR/app-analysis.txt"

    # Create zip
    ZIP_FILE="$HOME/Desktop/migration-backup-$(date +%Y%m%d-%H%M%S).zip"
    cd /tmp
    zip -r "$ZIP_FILE" "$(basename "$BACKUP_DIR")"
    
    echo "✅ Backup complete!"
    echo "📦 Zip file: $ZIP_FILE"
    echo "💾 Upload this zip to iCloud Drive"
    echo "🗑️  Cleaning temp files..."
    rm -rf "$BACKUP_DIR"

elif [ "$1" = "restore" ]; then
    if [ -z "$2" ]; then
        echo "Usage: ./migrate.sh restore /path/to/backup.zip"
        exit 1
    fi
    
    ZIP_FILE="$2"
    if [ ! -f "$ZIP_FILE" ]; then
        echo "❌ Zip file not found: $ZIP_FILE"
        exit 1
    fi
    
    echo "🚀 Setting up new laptop..."
    
    # Extract backup
    RESTORE_DIR="/tmp/migration-restore"
    mkdir -p "$RESTORE_DIR"
    unzip -q "$ZIP_FILE" -d "$RESTORE_DIR"
    BACKUP_FOLDER=$(find "$RESTORE_DIR" -name "migration-backup-*" -type d | head -1)
    
    # Load user config (no more questions!)
    if [ -f "$BACKUP_FOLDER/user-config.txt" ]; then
        source "$BACKUP_FOLDER/user-config.txt"
        echo "✅ Using saved config: $USER_NAME <$USER_EMAIL>"
    else
        echo "⚠️  No config found, asking for details..."
        read -p "Your full name: " USER_NAME
        read -p "Your email: " USER_EMAIL
    fi

    echo "🚀 Starting automated setup..."

    # Install Homebrew first
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Install Xcode command line tools
    echo "Installing Xcode command line tools..."
    xcode-select --install 2>/dev/null || echo "Xcode tools already installed"

    # Copy Brewfile and install apps (this creates Cursor app)
    cp "$BACKUP_FOLDER/.Brewfile" ~/
    echo "Installing apps and tools..."
    brew bundle --global

    # Basic Git setup
    echo "Setting up Git..."
    git config --global user.name "$USER_NAME"
    git config --global user.email "$USER_EMAIL"
    git config --global init.defaultBranch main

    # Create development directories
    echo "Creating dev folders..."
    mkdir -p ~/Development/{personal,work,experiments}

    # Basic zsh setup
    echo "Setting up shell..."
    echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
    echo 'alias ll="ls -la"' >> ~/.zshrc
    echo 'alias gs="git status"' >> ~/.zshrc

    # NOW restore files (after apps are installed)
    echo "Restoring files and settings..."

    # Restore SSH keys
    if [ -d "$BACKUP_FOLDER/ssh-folder" ]; then
        echo "Restoring SSH keys..."
        cp -R "$BACKUP_FOLDER/ssh-folder/.ssh" ~/
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/id_* 2>/dev/null || true
        echo "✅ SSH keys restored"
    fi

    # Restore projects
    if [ -d "$BACKUP_FOLDER/projects" ]; then
        echo "Restoring projects..."
        cp -R "$BACKUP_FOLDER/projects" ~/Projects
        echo "✅ Projects restored"
    fi

    # Restore Cursor settings (after Cursor is installed)
    if [ -d "$BACKUP_FOLDER/cursor-settings" ]; then
        echo "Restoring Cursor settings..."
        mkdir -p "$HOME/Library/Application Support"
        cp -R "$BACKUP_FOLDER/cursor-settings/Cursor" "$HOME/Library/Application Support/"
        echo "✅ Cursor settings restored"
    fi

    echo ""
    echo "✅ Automated setup complete!"
    echo "Manual steps remaining:"
    echo "1. Sign into iCloud (passwords sync automatically)"
    echo "2. Download 1Password app and sign in (data syncs)"
    echo "3. Sign into Docker Desktop" 
    echo "4. Open Cursor (settings already restored!)"
    echo "5. Check $BACKUP_FOLDER/app-analysis.txt for missing apps"
    
    # Cleanup
    echo "🗑️  Cleaning temp files..."
    rm -rf "$RESTORE_DIR"

else
    echo "Usage:"
    echo "  ./migrate.sh backup                      # Creates zip on Desktop"
    echo "  ./migrate.sh restore /path/to/backup.zip # Restores from zip"
fi