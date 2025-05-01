#!/bin/bash

# Text colors (all set to red)
RED='\033[0;31m'
GREEN='\033[0;31m'
YELLOW='\033[0;31m'
BLUE='\033[0;31m'
PURPLE='\033[0;31m'
CYAN='\033[0;31m'
WHITE='\033[1;31m'
BOLD='\033[1m'
NC='\033[0m'

# Check for curl and install if not present
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Function to display success messages
success_message() {
    echo -e "${GREEN}[✅] $1${NC}"
}

# Function to display info messages
info_message() {
    echo -e "${RED}[ℹ️] $1${NC}"
}

# Function to display error messages
error_message() {
    echo -e "${RED}[❌] $1${NC}"
}

# Function to install dependencies
install_dependencies() {
    info_message "Installing required packages..."
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
    
    info_message "Installing specific tools..."
    curl -L https://app.drosera.io/install | bash
    curl -L https://foundry.paradigm.xyz | bash
    curl -fsSL https://bun.sh/install | bash
    
    # Check and open ports
    info_message "Configuring ports..."
    if ! sudo iptables -C INPUT -p tcp --dport 31313 -j ACCEPT 2>/dev/null; then
        sudo iptables -I INPUT -p tcp --dport 31313 -j ACCEPT
        success_message "Port 31313 opened"
    else
        info_message "Port 31313 already open"
    fi
    
    if ! sudo iptables -C INPUT -p tcp --dport 31314 -j ACCEPT 2>/dev/null; then
        sudo iptables -I INPUT -p tcp --dport 31314 -j ACCEPT
        success_message "Port 31314 opened"
    else
        info_message "Port 31314 already open"
    fi
    
    success_message "Dependencies installed"
}

# Function to deploy Trap
deploy_trap() {
    info_message "Starting Trap deployment..."
    
    echo -e "${WHITE}[${RED}1/5${WHITE}] ${RED}➜ ${WHITE}🔄 Updating tools...${NC}"
    droseraup
    foundryup
    
    echo -e "${WHITE}[${RED}2/5${WHITE}] ${RED}➜ ${WHITE}📂 Creating directory...${NC}"
    mkdir my-drosera-trap
    cd my-drosera-trap
    
    echo -e "${WHITE}[${RED}3/5${WHITE}] ${RED}➜ ${WHITE}⚙️ Setting up Git...${NC}"
    echo -e "${RED}📧 Enter your Github email:${NC}"
    read -p "➜ " GITHUB_EMAIL
    
    echo -e "${RED}👤 Enter your Github username:${NC}"
    read -p "➜ " GITHUB_USERNAME
    
    git config --global user.email "$GITHUB_EMAIL"
    git config --global user.name "$GITHUB_USERNAME"
    
    echo -e "${WHITE}[${RED}4/5${WHITE}] ${RED}➜ ${WHITE}🛠️ Initializing project...${NC}"
    forge init -t drosera-network/trap-foundry-template
    bun install
    forge build
    
    echo -e "${WHITE}[${RED}5/5${WHITE}] ${RED}➜ ${WHITE}🔑 Applying configuration...${NC}"
    echo -e "${RED}🔐 Enter your EVM wallet private key:${NC}"
    read -p "➜ " PRIV_KEY
    
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"
    drosera apply
    
    echo -e "\n${WHITE}========================================${NC}"
    success_message "Trap successfully configured!"
    echo -e "${WHITE}========================================${NC}\n"
}

# Function to install the node
install_node() {
    info_message "Starting node installation..."
    
    echo -e "${WHITE}[${RED}1/3${WHITE}] ${RED}➜ ${WHITE}📁 Setting up configuration...${NC}"
    TARGET_FILE="$HOME/my-drosera-trap/drosera.toml"
    
    [ -f "$TARGET_FILE" ] && {
        sed -i '/^private_trap/d' "$TARGET_FILE"
        sed -i '/^whitelist/d' "$TARGET_FILE"
    }
    
    echo -e "${WHITE}[${RED}2/3${WHITE}] ${RED}➜ ${WHITE}💼 Setting up wallet...${NC}"
    echo -e "${RED}📝 Enter your EVM wallet address:${NC}"
    read -p "➜ " WALLET_ADDRESS
    
    echo "private_trap = true" >> "$TARGET_FILE"
    echo "whitelist = [\"$WALLET_ADDRESS\"]" >> "$TARGET_FILE"
    
    echo -e "${WHITE}[${RED}3/3${WHITE}] ${RED}➜ ${WHITE}🔑 Applying configuration...${NC}"
    cd my-drosera-trap
    
    echo -e "${RED}🔐 Enter your EVM wallet private key:${NC}"
    read -p "➜ " PRIV_KEY
    
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"
    drosera apply
    
    echo -e "\n${WHITE}========================================${NC}"
    success_message "Node successfully installed!"
    echo -e "${WHITE}========================================${NC}\n"
    
    cd
}

# Function to start the node
start_node() {
    info_message "Starting Drosera node..."
    
    echo -e "${WHITE}[${RED}1/4${WHITE}] ${RED}➜ ${WHITE}📥 Downloading binaries...${NC}"
    cd ~
    curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    sudo cp drosera-operator /usr/bin
    
    echo -e "${WHITE}[${RED}2/4${WHITE}] ${RED}➜ ${WHITE}🔑 Registering operator...${NC}"
    echo -e "${RED}🔐 Enter your EVM wallet private key:${NC}"
    read -p "➜ " PRIV_KEY
    
    export DROSERA_PRIVATE_KEY="$PRIV_KEY"
    drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $DROSERA_PRIVATE_KEY
    
    echo -e "${WHITE}[${RED}3/4${WHITE}] ${赤}➜ ${WHITE}⚙️ Creating service...${NC}"
    SERVER_IP=$(curl -s https://api.ipify.org)
    
    sudo bash -c "cat <<EOF > /etc/systemd/system/drosera.service
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path \$HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \\
    --eth-backup-rpc-url https://1rpc.io/holesky \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $DROSERA_PRIVATE_KEY \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $SERVER_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF"
    
    echo -e "${WHITE}[${RED}4/4${WHITE}] ${RED}➜ ${WHITE}🚀 Starting service...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable drosera
    sudo systemctl start drosera
    
    echo -e "\n${WHITE}========================================${NC}"
    success_message "Node successfully started!"
    info_message "To view logs use:"
    echo -e "${RED}journalctl -u drosera.service -f${NC}"
    echo -e "${WHITE}========================================${NC}\n"
    
    journalctl -u drosera.service -f
}

# Function to remove the node
remove_node() {
    info_message "Removing Drosera node..."
    
    echo -e "${WHITE}[${RED}1/2${WHITE}] ${RED}➜ ${WHITE}🛑 Stopping services...${NC}"
    sudo systemctl stop drosera.service
    sudo systemctl disable drosera.service
    sudo rm /etc/systemd/system/drosera.service
    sudo systemctl daemon-reload
    
    echo -e "${WHITE}[${RED}2/2${WHITE}] ${RED}➜ ${WHITE}🗑️ Deleting files...${NC}"
    rm -rf my-drosera-trap
    
    echo -e "\n${WHITE}========================================${NC}"
    success_message "Drosera node successfully removed!"
    echo -e "${WHITE}========================================${NC}\n"
}

# Clear screen
clear

# Function to display menu
print_menu() {
    # Display logo
    curl -s https://raw.githubusercontent.com/Evenorchik/evenorlogo/main/evenorlogo.sh | bash
    
    # Custom ASCII header
    echo -e "┌────────────────────────────────────────┐"
    echo -e "│            drosera wizzard            │"
    echo -e "└────────────────────────────────────────┘\n"
    
    echo -e "${BOLD}${RED}🔧 Available actions:${NC}\n"
    echo -e "${RED}[${RED}1${RED}] ${RED}➜ ${RED}📦 Install dependencies${NC}"
    echo -e "${RED}[${RED}2${Red}] ${RED}➜ ${RED}🚀 Deploy Trap${NC}"
    echo -e "${RED}[${RED}3${RED}] ${RED}➜ ${RED}🛠️ Install node${NC}"
    echo -e "${RED}[${RED}4${RED}] ${RED}➜ ${RED}▶️ Start node${NC}"
    echo -e "${RED}[${RED}5${RED}] ${RED}➜ ${RED}🔄 Check status${NC}"
    echo -e "${RED}[${RED}6${RED}] ${RED}➜ ${RED}📋 View logs${NC}"
    echo -e "${RED}[${RED}7${RED}] ${RED}➜ ${RED}🔄 Restart node${NC}"
    echo -e "${RED}[${RED}8${RED}] ${RED}➜ ${RED}🗑️ Remove node${NC}"
    echo -e "${RED}[${RED}9${RED}] ${RED}➜ ${Red}🚪 Exit${NC}\n"
}

# Main program loop
while true; do
    clear
    print_menu
    
    echo -e "${BOLD}${RED}📝 Enter action number [1-9]:${NC} "
    read -p "➜ " choice
    
    case $choice in
        1)
            install_dependencies
            ;;
        2)
            deploy_trap
            ;;
        3)
            install_node
            ;;
        4)
            start_node
            ;;
        5)
            info_message "Checking node status..."
            echo -e "${RED}You have the latest Drosera node version!${NC}"
            ;;
        6)\``]}]}
