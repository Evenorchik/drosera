#!/bin/bash

# Text color
ORANGE='\033[0;33m'
NC='\033[0m' # No Color (reset)

# Check for curl and install if missing
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

# Display logo
curl -s https://raw.githubusercontent.com/Evenorchik/evenorlogo/refs/heads/main/evenorlogo.sh | bash

# Menu
echo -e "${ORANGE}Select an action:${NC}"
echo -e "${ORANGE}1) Install dependencies${NC}"
echo -e "${ORANGE}2) Deploy Trap${NC}"
echo -e "${ORANGE}3) Install node${NC}"
echo -e "${ORANGE}4) Start node${NC}"
echo -e "${ORANGE}5) Update node${NC}"
echo -e "${ORANGE}6) View node logs${NC}"
echo -e "${ORANGE}7) Restart node${NC}"
echo -e "${ORANGE}8) Remove node${NC}"

echo -e "${ORANGE}Enter number:${NC} "
read choice

case $choice in
    1)
        echo -e "${ORANGE}Installing dependencies...${NC}"
        sudo apt-get update && sudo apt-get upgrade -y
        sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

        curl -L https://app.drosera.io/install | bash
        curl -L https://foundry.paradigm.xyz | bash
        curl -fsSL https://bun.sh/install | bash

        echo "Checking port 31313..."
        if ! sudo iptables -C INPUT -p tcp --dport 31313 -j ACCEPT 2>/dev/null; then
            echo "Port 31313 is closed. Opening..."
            sudo iptables -I INPUT -p tcp --dport 31313 -j ACCEPT && echo "Port 31313 opened."
        else
            echo "Port 31313 already open."
        fi
        
        echo "Checking port 31314..."
        if ! sudo iptables -C INPUT -p tcp --dport 31314 -j ACCEPT 2>/dev/null; then
            echo "Port 31314 is closed. Opening..."
            sudo iptables -I INPUT -p tcp --dport 31314 -j ACCEPT && echo "Port 31314 opened."
        else
            echo "Port 31314 already open."
        fi
        
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        echo -e "${ORANGE}Return to the text guide!${NC}"
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        sleep 2      
        ;;
    2)
        echo -e "${ORANGE}Deploying Trap...${NC}"
        droseraup
        foundryup

        mkdir my-drosera-trap
        cd my-drosera-trap

        # GitHub email
        echo -e "${ORANGE}Enter your GitHub email:${NC} "
        read GITHUB_EMAIL
        # GitHub username
        echo -e "${ORANGE}Enter your GitHub username:${NC} "
        read GITHUB_USERNAME
        
        git config --global user.email "$GITHUB_EMAIL"
        git config --global user.name "$GITHUB_USERNAME"

        forge init -t drosera-network/trap-foundry-template

        bun install
        forge build

        # EVM private key
        echo -e "${ORANGE}Enter your EVM wallet private key:${NC} "
        read PRIV_KEY
        
        export DROSERA_PRIVATE_KEY="$PRIV_KEY"
        
        drosera apply
      
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        echo -e "${ORANGE}Return to the text guide!${NC}"
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        sleep 2
        ;;
    3)
        echo -e "${ORANGE}Installing node...${NC}"
        
        TARGET_FILE="$HOME/my-drosera-trap/drosera.toml"

        [ -f "$TARGET_FILE" ] && {
            sed -i '/^private_trap/d' "$TARGET_FILE"
            sed -i '/^whitelist/d' "$TARGET_FILE"
        }
        
        echo -e "${ORANGE}Enter your EVM wallet address:${NC} "
        read WALLET_ADDRESS
        
        echo "private_trap = true" >> "$TARGET_FILE"
        echo "whitelist = [\"$WALLET_ADDRESS\"]" >> "$TARGET_FILE"

        cd my-drosera-trap

        echo -e "${ORANGE}Enter your EVM wallet private key:${NC} "
        read PRIV_KEY
        
        export DROSERA_PRIVATE_KEY="$PRIV_KEY"
        
        drosera apply

        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        echo -e "${ORANGE}Return to the text guide!${NC}"
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        sleep 2
        cd
        ;;
    4)
        echo -e "${ORANGE}Starting node...${NC}"
        cd ~

        curl -LO https://github.com/drosera-network/releases/releases/download/v1.19.0/drosera-operator-v1.19.0-x86_64-unknown-linux-gnu.tar.gz
        tar -xvf drosera-operator-v1.19.0-x86_64-unknown-linux-gnu.tar.gz
               
        sudo cp drosera-operator /usr/bin

        echo -e "${ORANGE}Enter your EVM wallet private key:${NC} "
        read PRIV_KEY
        
        export DROSERA_PRIVATE_KEY="$PRIV_KEY"

        drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $DROSERA_PRIVATE_KEY

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

        sudo systemctl daemon-reload
        sudo systemctl enable drosera
        sudo systemctl start drosera
        
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        echo -e "${ORANGE}To view logs use:${NC}"
        echo "journalctl -u drosera.service -f"
        echo -e "${ORANGE}-----------------------------------------------------------------------${NC}"
        sleep 2
        journalctl -u drosera.service -f
        ;;
    5)
        echo -e "${ORANGE}Updating Drosera node...${NC}"
        sudo systemctl stop drosera
        sleep 2
        curl -LO https://github.com/drosera-network/releases/releases/download/v1.19.0/drosera-operator-v1.19.0-x86_64-unknown-linux-gnu.tar.gz
        tar -xvf drosera-operator-v1.19.0-x86_64-unknown-linux-gnu.tar.gz
        sudo cp drosera-operator /usr/bin
        drosera-operator --version
        sleep 3

        grep -q '^drosera_team' $HOME/my-drosera-trap/drosera.toml || sed -i 's|^drosera_rpc.*|drosera_team = "https://relay.testnet.drosera.io/"|' $HOME/my-drosera-trap/drosera.toml

        cd my-drosera-trap
        echo -e "${ORANGE}Enter your EVM wallet private key:${NC} "
        read PRIV_KEY
        
        export DROSERA_PRIVATE_KEY="$PRIV_KEY"
        
        drosera apply
        sleep 3

        cd ~
        sudo systemctl restart drosera
        journalctl -u drosera.service -f
        ;;
    6)
        journalctl -u drosera.service -f
        ;;
    7)
        sudo systemctl restart drosera && journalctl -u drosera.service -f
        ;;
    8)
        echo -e "${ORANGE}Removing Drosera node...${NC}"

        sudo systemctl stop drosera.service
        sudo systemctl disable drosera.service
        sudo rm /etc/systemd/system/drosera.service
        sudo systemctl daemon-reload
        sleep 1

        echo -e "${ORANGE}Deleting node files...${NC}"
        rm -rf my-drosera-trap
        
        echo -e "${ORANGE}Node removed successfully!${NC}"
        sleep 1
        ;;
    *)
        echo -e "${ORANGE}Invalid choice. Please select a valid menu item.${NC}"
        ;;
esac
