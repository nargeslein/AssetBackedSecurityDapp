#!/usr/bin/env sh
set -eu

NETWORK="${1:-sepolia}"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

case "$NETWORK" in
  sepolia)
    RPC_URL="${SEPOLIA_RPC_URL:-}"
    ;;
  holesky)
    RPC_URL="${HOLESKY_RPC_URL:-}"
    ;;
  custom)
    RPC_URL="${CUSTOM_RPC_URL:-}"
    ;;
  *)
    echo "Unknown network: $NETWORK"
    echo "Use one of: sepolia, holesky, custom"
    exit 1
    ;;
esac

if [ -z "${RPC_URL:-}" ]; then
  echo "Missing RPC URL for $NETWORK."
  echo "Set it in .env or export it before running this script."
  exit 1
fi

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "Missing PRIVATE_KEY."
  echo "Set a funded test-wallet private key in .env or export it before running this script."
  exit 1
fi

mkdir -p deployments

echo "Deploying Bank to $NETWORK..."
BANK_OUTPUT="$(forge create src/Bank.sol:Bank --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY")"
echo "$BANK_OUTPUT"
BANK_ADDRESS="$(printf '%s\n' "$BANK_OUTPUT" | awk '/Deployed to:/ { print $3 }')"

echo "Deploying Pool to $NETWORK..."
POOL_OUTPUT="$(forge create src/Pool.sol:Pool --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY")"
echo "$POOL_OUTPUT"
POOL_ADDRESS="$(printf '%s\n' "$POOL_OUTPUT" | awk '/Deployed to:/ { print $3 }')"

cat > "deployments/$NETWORK.json" <<EOF
{
  "network": "$NETWORK",
  "contracts": {
    "Bank": "$BANK_ADDRESS",
    "Pool": "$POOL_ADDRESS"
  }
}
EOF

echo "Wrote deployments/$NETWORK.json"
