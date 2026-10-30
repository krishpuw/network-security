#!/usr/bin/env bash
set -euo pipefail

RG="${1:-rg-seclab}"
LOCATION="${2:-eastus}"
DIR="$(cd "$(dirname "$0")" && pwd)"
PARAMS="$DIR/main.local.bicepparam"
[[ -f "$PARAMS" ]] || PARAMS="$DIR/main.bicepparam"

az group create --name "$RG" --location "$LOCATION" -o none
az deployment group what-if --resource-group "$RG" --parameters "$PARAMS"
read -rp "Apply these changes? [y/N] " ok
[[ "$ok" == [yY] ]] || exit 0
az deployment group create --resource-group "$RG" --parameters "$PARAMS"