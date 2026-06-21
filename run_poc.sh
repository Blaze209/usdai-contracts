#!/bin/bash
# Ensure forge is in PATH
if ! command -v forge &> /dev/null
then
    export PATH="$HOME/.foundry/bin:$PATH"
fi

if ! command -v forge &> /dev/null
then
    echo "Error: forge could not be found. Please install Foundry."
    exit 1
fi

echo "Running Bridged Supply Underflow PoC..."
forge test --match-path test/UnderflowPoC.t.sol -vv
