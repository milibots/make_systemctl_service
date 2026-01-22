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
    grep -q "if __name__ == '__main__'" "$file" 2>/dev/null && return 0
    grep -q "def main()" "$file" 2>/dev/null && return 0
    grep -q "#!/usr/bin/env python" "$file" 2>/dev/null && return 0
    local filename=$(basename "$file")
    [[ "$filename" =~ ^(main|app|run|bot|server|service|manage)\.py$ ]] && return 0
    return 1
}

install_service() {
    if [ -t 0 ]; then exec < /dev/tty; fi

    print_message "=========================================" "$BLUE"
    print_message "  Python Systemd Service Creator         " "$BLUE"
    print_message "=========================================" "$BLUE"
    echo ""

    CURRENT_DIR=$(pwd)
    print_message "Current directory: $CURRENT_DIR" "$YELLOW"
    echo ""

    python_files=($(find_python_files))
    [ ${#python_files[@]} -eq 0 ] && exit 1

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

    while true; do
        read -r -p "Select Python file to run (1-${#python_files[@]}) or enter custom path: " selection
        [[ -z "$selection" ]] && continue
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#python_files[@]} ]; then
            SELECTED_FILE=$(realpath "${file_options[$selection]}")
            break
        elif [ -f "$selection" ] && [[ "$selection" == *.py ]]; then
            SELECTED_FILE=$(realpath "$selection")
            break
        elif [ -f "$CURRENT_DIR/$selection" ] && [[ "$selection" == *.py ]]; then
            SELECTED_FILE=$(realpath "$CURRENT_DIR/$selection")
            break
        fi
    done

    PROJECT_DIR=$(dirname "$SELECTED_FILE")
    PARENT_DIR=$(dirname "$PROJECT_DIR")

    VENV_PATHS=()
    for base in "$PROJECT_DIR" "$PARENT_DIR"; do
        for name in venv .venv env .env virtualenv; do
            if [ -f "$base/$name/bin/python" ]; then
                VENV_PATHS+=("$base/$name")
            fi
        done
    done

    USE_VENV=false
    VENV_PATH=""

    if [ ${#VENV_PATHS[@]} -gt 0 ]; then
        local j=1
        for venv in "${VENV_PATHS[@]}"; do
            print_message "  $j) $venv" "$CYAN"
            ((j++))
        done
        print_message "  $j) Create new virtual environment" "$CYAN"
        print_message "  $((j+1))) Enter custom virtualenv path" "$CYAN"
        print_message "  $((j+2))) Don't use virtual environment" "$CYAN"

        while true; do
            read -r -p "Select option (1-$((j+2))): " venv_choice
            [[ -z "$venv_choice" ]] && continue

            if [ "$venv_choice" -le ${#VENV_PATHS[@]} ]; then
                VENV_PATH="${VENV_PATHS[$((venv_choice-1))]}"
                USE_VENV=true
                break
            elif [ "$venv_choice" -eq $j ]; then
                read -r -p "Enter virtual environment name [default: venv]: " venv_name
                venv_name=${venv_name:-venv}
                VENV_PATH="$PROJECT_DIR/$venv_name"
                python3 -m venv "$VENV_PATH"
                USE_VENV=true
                break
            elif [ "$venv_choice" -eq $((j+1)) ]; then
                read -r -p "Enter full path to virtualenv: " custom_venv
                if [ -f "$custom_venv/bin/python" ]; then
                    VENV_PATH="$custom_venv"
                    USE_VENV=true
                    break
                fi
            else
                USE_VENV=false
                break
            fi
        done
    fi

    PYTHON_PATH=$( [ "$USE_VENV" = true ] && echo "$VENV_PATH/bin/python" || which python3 )

    DEFAULT_SERVICE_NAME=$(basename "$SELECTED_FILE" .py | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    read -r -p "Enter systemd service name [default: $DEFAULT_SERVICE_NAME]: " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
    SERVICE_NAME=${SERVICE_NAME%.service}

    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    DEFAULT_USER=${SUDO_USER:-$(whoami)}
    read -r -p "Enter user to run service as [default: $DEFAULT_USER]: " SERVICE_USER
    SERVICE_USER=${SERVICE_USER:-$DEFAULT_USER}

    read -r -p "Enter additional Python arguments (optional): " PYTHON_ARGS

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

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/service_file.tmp "$SERVICE_FILE"
    sudo chmod 644 "$SERVICE_FILE"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"

    if ask_yes_no "Start service now?"; then
        sudo systemctl start "$SERVICE_NAME"
        sudo systemctl status "$SERVICE_NAME" --no-pager -l
    fi
}

[ "$EUID" -eq 0 ] && install_service || sudo bash "$0"
