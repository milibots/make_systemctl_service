#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_message() {
    echo -e "${2}${1}${NC}"
}

ask_yes_no() {
    while true; do
        read -r -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

find_python_files() {
    local files=()
    
    while IFS= read -r -d '' file; do
        if [[ ! $(basename "$file") =~ ^(__|test_|setup\.py|__pycache__) ]] && \
           [[ ! $file =~ /(venv|.venv|env|.env|virtualenv)/ ]]; then
            files+=("$file")
        fi
    done < <(find . -maxdepth 2 -name "*.py" -type f ! -path "./.*" ! -path "./__pycache__/*" -print0 2>/dev/null)
    
    if [ ${#files[@]} -eq 0 ]; then
        while IFS= read -r -d '' file; do
            if [[ ! $(basename "$file") =~ ^(__|test_) ]] && \
               [[ ! $file =~ /(venv|.venv|env|.env|virtualenv)/ ]]; then
                files+=("$file")
            fi
        done < <(find . -name "*.py" -type f ! -path "./.*" ! -path "./__pycache__/*" -print0 2>/dev/null)
    fi
    
    echo "${files[@]}"
}

is_main_app() {
    local file="$1"
    
    if grep -q "if __name__ == '__main__'" "$file" 2>/dev/null; then
        return 0
    fi
    
    if grep -q "def main()" "$file" 2>/dev/null; then
        return 0
    fi
    
    if grep -q "#!/usr/bin/env python" "$file" 2>/dev/null; then
        return 0
    fi
    
    local filename=$(basename "$file")
    if [[ "$filename" =~ ^(main|app|run|bot|server|service|manage)\.py$ ]]; then
        return 0
    fi
    
    return 1
}

install_service() {
    if [ -t 0 ]; then
        exec < /dev/tty
    fi
    
    print_message "=========================================" "$BLUE"
    print_message "  Python Systemd Service Creator         " "$BLUE"
    print_message "=========================================" "$BLUE"
    echo ""
    
    CURRENT_DIR=$(pwd)
    print_message "Current directory: $CURRENT_DIR" "$YELLOW"
    echo ""
    
    print_message "Looking for Python files..." "$CYAN"
    python_files=($(find_python_files))
    
    if [ ${#python_files[@]} -eq 0 ]; then
        print_message "No Python files found in current directory!" "$RED"
        print_message "Please run this script from your project directory." "$YELLOW"
        exit 1
    fi
    
    print_message "Found ${#python_files[@]} Python file(s):" "$GREEN"
    echo ""
    
    local i=1
    declare -A file_options
    
    for file in "${python_files[@]}"; do
        if is_main_app "$file"; then
            print_message "  $i) $file (looks like main application)" "$GREEN"
        else
            print_message "  $i) $file" "$NC"
        fi
        file_options[$i]="$file"
        ((i++))
    done
    
    echo ""
    
    while true; do
        read -r -p "Select Python file to run (1-${#python_files[@]}) or enter custom path: " selection
        
        if [[ -z "$selection" ]]; then
            continue
        fi
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#python_files[@]} ]; then
            SELECTED_FILE="${file_options[$selection]}"
            SELECTED_FILE=$(realpath "$SELECTED_FILE")
            break
        elif [ -f "$selection" ] && [[ "$selection" == *.py ]]; then
            SELECTED_FILE=$(realpath "$selection")
            break
        elif [ -f "$CURRENT_DIR/$selection" ] && [[ "$selection" == *.py ]]; then
            SELECTED_FILE=$(realpath "$CURRENT_DIR/$selection")
            break
        else
            print_message "Invalid selection. Please enter a number or valid .py file path." "$RED"
        fi
    done
    
    print_message "Selected file: $SELECTED_FILE" "$GREEN"
    echo ""
    
    PROJECT_DIR=$(dirname "$SELECTED_FILE")
    
    print_message "=== Virtual Environment Setup ===" "$BLUE"
    
    VENV_PATHS=()
    for venv_name in venv .venv env .env virtualenv; do
        if [ -d "$PROJECT_DIR/$venv_name" ] && [ -f "$PROJECT_DIR/$venv_name/bin/python" ]; then
            VENV_PATHS+=("$PROJECT_DIR/$venv_name")
        fi
    done
    
    USE_VENV=false
    VENV_PATH=""
    
    if [ ${#VENV_PATHS[@]} -gt 0 ]; then
        print_message "Found ${#VENV_PATHS[@]} virtual environment(s):" "$GREEN"
        local j=1
        for venv in "${VENV_PATHS[@]}"; do
            python_version=$("$venv/bin/python" --version 2>/dev/null || echo "Unknown version")
            print_message "  $j) $venv ($python_version)" "$CYAN"
            ((j++))
        done
        print_message "  $j) Create new virtual environment" "$CYAN"
        print_message "  $((j+1))) Don't use virtual environment" "$CYAN"
        echo ""
        
        while true; do
            read -r -p "Select option (1-$((j+1))): " venv_choice
            
            if [[ -z "$venv_choice" ]]; then
                continue
            fi
            
            if [[ "$venv_choice" =~ ^[0-9]+$ ]] && [ "$venv_choice" -ge 1 ] && [ "$venv_choice" -le $((j+1)) ]; then
                if [ "$venv_choice" -le ${#VENV_PATHS[@]} ]; then
                    VENV_PATH="${VENV_PATHS[$((venv_choice-1))]}"
                    USE_VENV=true
                    print_message "Using existing virtual environment: $VENV_PATH" "$GREEN"
                elif [ "$venv_choice" -eq $j ]; then
                    read -r -p "Enter virtual environment name [default: venv]: " venv_name
                    venv_name=${venv_name:-venv}
                    VENV_PATH="$PROJECT_DIR/$venv_name"
                    
                    if [ -d "$VENV_PATH" ]; then
                        print_message "Warning: Directory $VENV_PATH already exists!" "$YELLOW"
                        if ask_yes_no "Do you want to recreate it?"; then
                            rm -rf "$VENV_PATH"
                        else
                            VENV_PATH=""
                            continue
                        fi
                    fi
                    
                    print_message "Creating virtual environment at: $VENV_PATH" "$YELLOW"
                    python3 -m venv "$VENV_PATH"
                    if [ $? -eq 0 ]; then
                        USE_VENV=true
                        print_message "Virtual environment created successfully" "$GREEN"
                    else
                        print_message "Failed to create virtual environment" "$RED"
                        VENV_PATH=""
                    fi
                else
                    USE_VENV=false
                    print_message "Will use system Python" "$YELLOW"
                fi
                break
            else
                print_message "Invalid option. Please enter a number between 1 and $((j+1))." "$RED"
            fi
        done
    else
        print_message "No virtual environments found in project directory." "$YELLOW"
        if ask_yes_no "Do you want to create a virtual environment?"; then
            read -r -p "Enter virtual environment name [default: venv]: " venv_name
            venv_name=${venv_name:-venv}
            VENV_PATH="$PROJECT_DIR/$venv_name"
            
            print_message "Creating virtual environment at: $VENV_PATH" "$YELLOW"
            python3 -m venv "$VENV_PATH"
            if [ $? -eq 0 ]; then
                USE_VENV=true
                print_message "Virtual environment created successfully" "$GREEN"
            else
                print_message "Failed to create virtual environment" "$RED"
                USE_VENV=false
            fi
        else
            USE_VENV=false
            print_message "Will use system Python" "$YELLOW"
        fi
    fi
    
    if [ "$USE_VENV" = true ] && [ -n "$VENV_PATH" ]; then
        REQ_FILES=()
        for req_file in requirements.txt requirements-dev.txt pyproject.toml setup.py Pipfile; do
            if [ -f "$PROJECT_DIR/$req_file" ]; then
                REQ_FILES+=("$req_file")
            fi
        done
        
        if [ ${#REQ_FILES[@]} -gt 0 ]; then
            print_message "Found dependency files: ${REQ_FILES[*]}" "$GREEN"
            
            for req_file in "${REQ_FILES[@]}"; do
                if ask_yes_no "Install dependencies from $req_file?"; then
                    print_message "Installing from $req_file..." "$YELLOW"
                    
                    case "$req_file" in
                        requirements.txt|requirements-dev.txt)
                            "$VENV_PATH/bin/pip" install -r "$PROJECT_DIR/$req_file"
                            ;;
                        pyproject.toml)
                            "$VENV_PATH/bin/pip" install -e "$PROJECT_DIR"
                            ;;
                        setup.py)
                            "$VENV_PATH/bin/pip" install -e "$PROJECT_DIR"
                            ;;
                        Pipfile)
                            if command -v pipenv &> /dev/null; then
                                cd "$PROJECT_DIR" && pipenv install --system
                            else
                                print_message "pipenv not found. Install with: pip install pipenv" "$RED"
                            fi
                            ;;
                    esac
                    
                    if [ $? -eq 0 ]; then
                        print_message "Dependencies installed successfully" "$GREEN"
                    else
                        print_message "Warning: Some dependencies failed to install" "$YELLOW"
                    fi
                fi
            done
        else
            print_message "No requirements files found. Skipping dependency installation." "$YELLOW"
        fi
    fi
    
    echo ""
    print_message "=== Systemd Service Configuration ===" "$BLUE"
    
    DEFAULT_SERVICE_NAME=$(basename "$SELECTED_FILE" .py | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    read -r -p "Enter systemd service name [default: $DEFAULT_SERVICE_NAME]: " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
    
    SERVICE_NAME=${SERVICE_NAME%.service}
    
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    if [ -f "$SERVICE_FILE" ]; then
        print_message "Warning: Service $SERVICE_NAME already exists!" "$YELLOW"
        print_message "Service file: $SERVICE_FILE" "$YELLOW"
        
        if ! ask_yes_no "Do you want to overwrite it?"; then
            print_message "Installation cancelled" "$RED"
            exit 1
        fi
    fi
    
    if [ -z "$SUDO_USER" ]; then
        DEFAULT_USER=$(whoami)
    else
        DEFAULT_USER="$SUDO_USER"
    fi
    
    read -r -p "Enter user to run service as [default: $DEFAULT_USER]: " SERVICE_USER
    SERVICE_USER=${SERVICE_USER:-$DEFAULT_USER}
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_message "Error: User $SERVICE_USER does not exist!" "$RED"
        exit 1
    fi
    
    if [ "$USE_VENV" = true ] && [ -n "$VENV_PATH" ]; then
        PYTHON_PATH="$VENV_PATH/bin/python"
    else
        PYTHON_PATH=$(which python3)
    fi
    
    read -r -p "Enter additional Python arguments (optional, e.g., -u for unbuffered): " PYTHON_ARGS
    
    ENV_VARS=""
    if ask_yes_no "Do you want to set environment variables?"; then
        print_message "Enter environment variables (KEY=VALUE), one per line. Enter empty line when done:" "$CYAN"
        while true; do
            read -r -p "> " env_var
            if [ -z "$env_var" ]; then
                break
            fi
            ENV_VARS="${ENV_VARS}Environment=\"$env_var\"\n"
        done
    fi
    
    print_message "Creating systemd service file at $SERVICE_FILE" "$YELLOW"
    
    cat > /tmp/service_file.tmp << EOF
[Unit]
Description=$SERVICE_NAME Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PYTHON_PATH $PYTHON_ARGS $SELECTED_FILE
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

$(echo -e "$ENV_VARS")

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/service_file.tmp "$SERVICE_FILE"
    sudo chmod 644 "$SERVICE_FILE"
    
    print_message "Systemd service file created successfully" "$GREEN"
    
    print_message "Reloading systemd daemon..." "$YELLOW"
    sudo systemctl daemon-reload
    
    print_message "Enabling $SERVICE_NAME service..." "$YELLOW"
    sudo systemctl enable "$SERVICE_NAME"
    
    if ask_yes_no "Do you want to start the service now?"; then
        print_message "Starting $SERVICE_NAME service..." "$YELLOW"
        sudo systemctl start "$SERVICE_NAME"
        
        sleep 2
        print_message "Service status:" "$BLUE"
        sudo systemctl status "$SERVICE_NAME" --no-pager -l
    fi
    
    echo ""
    print_message "=========================================" "$GREEN"
    print_message "Installation completed successfully!" "$GREEN"
    print_message "=========================================" "$GREEN"
    echo ""
    print_message "Summary:" "$CYAN"
    print_message "  Service Name:    $SERVICE_NAME" "$NC"
    print_message "  Service File:    $SERVICE_FILE" "$NC"
    print_message "  Python File:     $SELECTED_FILE" "$NC"
    print_message "  Project Dir:     $PROJECT_DIR" "$NC"
    print_message "  User:            $SERVICE_USER" "$NC"
    print_message "  Using Venv:      $USE_VENV" "$NC"
    if [ "$USE_VENV" = true ] && [ -n "$VENV_PATH" ]; then
        print_message "  Venv Path:       $VENV_PATH" "$NC"
    fi
    print_message "  Python Path:     $PYTHON_PATH $PYTHON_ARGS" "$NC"
    echo ""
    print_message "Management commands:" "$YELLOW"
    print_message "  Start service:   sudo systemctl start $SERVICE_NAME" "$NC"
    print_message "  Stop service:    sudo systemctl stop $SERVICE_NAME" "$NC"
    print_message "  Restart service: sudo systemctl restart $SERVICE_NAME" "$NC"
    print_message "  Check status:    sudo systemctl status $SERVICE_NAME" "$NC"
    print_message "  View logs:       sudo journalctl -u $SERVICE_NAME -f" "$NC"
    print_message "  Reload service:  sudo systemctl daemon-reload" "$NC"
    echo ""
    print_message "To view logs in real-time:" "$CYAN"
    print_message "  sudo journalctl -u $SERVICE_NAME -f" "$NC"
}

if [ "$EUID" -eq 0 ]; then
    install_service
else
    if command -v sudo &> /dev/null; then
        print_message "This script requires root privileges." "$YELLOW"
        print_message "It will ask for your password to install the systemd service." "$YELLOW"
        echo ""
        
        if ask_yes_no "Continue with sudo?"; then
            SCRIPT_PATH=$(realpath "$0")
            sudo bash "$SCRIPT_PATH"
        else
            print_message "Installation cancelled." "$RED"
            exit 1
        fi
    else
        print_message "Error: This script must be run with root privileges." "$RED"
        print_message "Please run as:" "$YELLOW"
        print_message "  curl -fsSL https://raw.githubusercontent.com/MiliScripts/make_systemctl_service/main/generate.sh | sudo bash" "$NC"
        exit 1
    fi
fi
