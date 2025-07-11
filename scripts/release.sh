#!/bin/bash

# Flowrite Release Script
# Usage: ./scripts/release.sh [version] [--dry-run]
# Example: ./scripts/release.sh 1.2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
NEW_VERSION=""
DRY_RUN=false
CURRENT_VERSION=""
CURRENT_BUILD=""

# Functions
log() {
    echo -e "${BLUE}[RELEASE]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    echo "Usage: $0 [version] [--dry-run]"
    echo ""
    echo "Examples:"
    echo "  $0 1.2.0"
    echo "  $0 1.2.1 --dry-run"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be done without making changes"
}

# Validate version format
validate_version() {
    if [[ ! $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid version format. Use semantic versioning (e.g., 1.2.0)"
        exit 1
    fi
}

# Get current version
get_current_version() {
    CURRENT_VERSION=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)
    CURRENT_BUILD=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | cut -d'+' -f2)
    log "Current version: $CURRENT_VERSION+$CURRENT_BUILD"
}

# Compare versions
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

# Update version in pubspec.yaml
update_version() {
    local new_build=$((CURRENT_BUILD + 1))
    local new_version_line="version: $NEW_VERSION+$new_build"
    
    log "Updating version to $NEW_VERSION+$new_build"
    
    if [ "$DRY_RUN" = true ]; then
        warning "DRY RUN: Would update pubspec.yaml version line to: $new_version_line"
        return
    fi
    
    # Create backup
    cp "$PROJECT_DIR/pubspec.yaml" "$PROJECT_DIR/pubspec.yaml.bak"
    
    # Update version
    sed -i "s/^version: .*/version: $NEW_VERSION+$new_build/" "$PROJECT_DIR/pubspec.yaml"
    
    success "Updated pubspec.yaml"
}

# Update changelog
update_changelog() {
    local changelog_file="$PROJECT_DIR/CHANGELOG.md"
    local today=$(date +"%Y-%m-%d")
    
    if [ ! -f "$changelog_file" ]; then
        log "Creating CHANGELOG.md"
        if [ "$DRY_RUN" = false ]; then
            cat > "$changelog_file" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [$NEW_VERSION] - $today

### Added
- Initial release

EOF
        fi
    else
        log "Updating CHANGELOG.md"
        if [ "$DRY_RUN" = false ]; then
            # Add new version entry after [Unreleased]
            sed -i "/## \[Unreleased\]/a\\
\\
## [$NEW_VERSION] - $today\\
\\
### Added\\
- New features and improvements\\
\\
### Changed\\
- Updates and modifications\\
\\
### Fixed\\
- Bug fixes" "$changelog_file"
        else
            warning "DRY RUN: Would update CHANGELOG.md with version $NEW_VERSION"
        fi
    fi
}

# Commit changes
commit_changes() {
    log "Committing version bump"
    
    if [ "$DRY_RUN" = true ]; then
        warning "DRY RUN: Would commit changes and create tag v$NEW_VERSION"
        return
    fi
    
    cd "$PROJECT_DIR"
    
    # Check if we have git
    if ! command -v git &> /dev/null; then
        error "Git is not installed"
        exit 1
    fi
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        error "Not a git repository"
        exit 1
    fi
    
    # Add changes
    git add pubspec.yaml CHANGELOG.md
    
    # Commit
    git commit -m "chore: bump version to $NEW_VERSION"
    
    # Create tag
    git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION"
    
    success "Created commit and tag v$NEW_VERSION"
    log "To push: git push origin main && git push origin v$NEW_VERSION"
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            -*)
                error "Unknown option $1"
                print_usage
                exit 1
                ;;
            *)
                if [ -z "$NEW_VERSION" ]; then
                    NEW_VERSION="$1"
                else
                    error "Too many arguments"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if version is provided
    if [ -z "$NEW_VERSION" ]; then
        error "Version is required"
        print_usage
        exit 1
    fi
    
    # Validate version
    validate_version
    
    # Get current version
    get_current_version
    
    # Check if new version is greater than current
    if ! version_gt "$NEW_VERSION" "$CURRENT_VERSION"; then
        error "New version ($NEW_VERSION) must be greater than current version ($CURRENT_VERSION)"
        exit 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        warning "DRY RUN MODE - No changes will be made"
    fi
    
    log "Releasing version $NEW_VERSION"
    
    # Update version
    update_version
    
    # Update changelog
    update_changelog
    
    # Commit changes
    commit_changes
    
    if [ "$DRY_RUN" = false ]; then
        success "Release $NEW_VERSION prepared successfully!"
        echo ""
        log "Next steps:"
        log "1. Review the changes: git show"
        log "2. Push to trigger release: git push origin main && git push origin v$NEW_VERSION"
        log "3. Or manually trigger release workflow from GitHub Actions"
    else
        success "Dry run completed - no changes made"
    fi
}

# Run main function
main "$@"
