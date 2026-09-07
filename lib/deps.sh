ensure_pandoc_installed() {
    if command_exists pandoc; then
        msg_skip "Pandoc already installed. Skipping..."
        return 0
    fi

    print_section "Installing Dependencies"
    msg_warn "Pandoc is not installed on this system."

    local dist
    dist=$(detect_distribution 2>/dev/null || echo "unknown")
    
    case "$dist" in
        macos)
            if ! command_exists brew; then
                msg_error "Homebrew is required to install Pandoc on macOS. Please install Homebrew first."
                exit 1
            fi
            msg_download "Installing Pandoc using Homebrew..."
            brew install pandoc
            ;;
        debian)
            msg_download "Updating package lists and installing Pandoc (APT)..."
            apt-get update -qq && apt-get install -y -q pandoc
            ;;
        arch)
            msg_download "Installing Pandoc (Pacman)..."
            pacman -S --noconfirm --needed pandoc
            ;;
        fedora)
            msg_download "Installing Pandoc (DNF)..."
            dnf install -y -q pandoc
            ;;
        *)
            msg_error "Could not automatically install Pandoc for distribution: '$dist'. Please install it manually."
            exit 1
            ;;
    esac

    if command_exists pandoc; then
        msg_success "Pandoc successfully installed!"
    else
        msg_error "Failed to install Pandoc. Please check your package manager."
        exit 1
    fi
}

check_minify_dependencies() {
    HAS_HTML_CSS_MINIFIER=false
    HAS_IMAGE_OPTIMIZER=false

    if command_exists esbuild || \
       command_exists html-minifier || \
       command_exists minify || \
       command_exists python3 || \
       command_exists python; then
        HAS_HTML_CSS_MINIFIER=true
    fi

    if command_exists pngquant || \
       command_exists optipng || \
       command_exists jpegoptim || \
       command_exists svgo || \
       command_exists cwebp; then
        HAS_IMAGE_OPTIMIZER=true
    fi
}

install_minify_dependencies() {
    msg_exec "Attempting to auto-install missing minification dependencies..."

    local distro
    distro=$(detect_distribution 2>/dev/null || echo "")
    
    local sudo_cmd=""

    if [[ $EUID -ne 0 ]]; then
        sudo_cmd="sudo"
    fi

    case "${distro}" in
        debian)
            ${sudo_cmd} apt-get update -qq && ${sudo_cmd} apt-get install -y pngquant jpegoptim optipng python3 &>/dev/null
            ;;
        arch)
            ${sudo_cmd} pacman -Sy --noconfirm --needed pngquant jpegoptim optipng python &>/dev/null
            ;;
        fedora)
            ${sudo_cmd} dnf install -y pngquant jpegoptim optipng python3 &>/dev/null
            ;;
        macos)
            brew install pngquant jpegoptim optipng python3 &>/dev/null
            ;;
        *)
            msg_warn "Could not identify distribution or package manager to auto-install tools."
            return 1
            ;;
    esac
}

ensure_minify_dependencies_installed() {
    check_minify_dependencies

    if [[ "$HAS_HTML_CSS_MINIFIER" == false ]] || [[ "$HAS_IMAGE_OPTIMIZER" == false ]]; then
        msg_warn "Some minification tools are missing. Attempting automatic installation..."
        if install_minify_dependencies; then
            check_minify_dependencies
        fi
    fi

    if [[ "$HAS_HTML_CSS_MINIFIER" == false ]]; then
        msg_warn "No HTML/CSS minifier found. HTML/CSS minification will be skipped."
    fi

    if [[ "$HAS_IMAGE_OPTIMIZER" == false ]]; then
        msg_warn "No image optimization tools found. Image optimization will be skipped."
    fi
}