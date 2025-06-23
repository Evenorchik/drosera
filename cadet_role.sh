#!/bin/bash
set -euo pipefail

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
echo -e "${ORANGE}Thank you for using my scripts, hope we all will get lifechange here :)${NC}"
echo -e "${ORANGE}Ill be very appretiated if you follow my X https://x.com/Evenorchik${NC}"

# Project directory
PROJECT_DIR="$HOME/my-drosera-trap"

# Change to project folder
cd "$PROJECT_DIR"

# Prompt for Discord username
echo -e "${ORANGE}Enter your Discord username:${NC}"
read DISCORD
export DISCORD

# Generate src/Trap.sol with injected Discord name
cat > src/Trap.sol <<EOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface IMockResponse {
    function isActive() external view returns (bool);
}

contract Trap is ITrap {
    address public constant RESPONSE_CONTRACT = 0x4608Afa7f277C8E0BE232232265850d1cDeB600E;
    string constant discordName = "${DISCORD}"; // add your discord name here

    function collect() external view returns (bytes memory) {
        bool active = IMockResponse(RESPONSE_CONTRACT).isActive();
        return abi.encode(active, discordName);
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        // take the latest block data from collect
        (bool active, string memory name) = abi.decode(data[0], (bool, string));
        // will not run if the contract is not active or the discord name is not set
        if (!active || bytes(name).length == 0) {
            return (false, bytes(""));
        }

        return (true, abi.encode(name));
    }
}
EOF

# Update drosera.toml fields
sed -i 's|^path = .*|path = "out/Trap.sol/Trap.json"|' drosera.toml
sed -i 's|^response_contract = .*|response_contract = "0x4608Afa7f277C8E0BE232232265850d1cDeB600E"|' drosera.toml
sed -i 's|^response_function = .*|response_function = "respondWithDiscordName(string)"|' drosera.toml

# Build the contract
echo -e "${ORANGE}Running forge build...${NC}"
forge build

# Run a dry run
echo -e "${ORANGE}Running drosera dryrun...${NC}"
drosera dryrun

# Prompt for private key
echo -e "${ORANGE}Enter your EVM wallet private key:${NC}"
read PRIV_KEY

# Export to environment variable
export DROSERA_PRIVATE_KEY="$PRIV_KEY"

# Apply changes
echo -e "${ORANGE}Running drosera apply...${NC}"
drosera apply
