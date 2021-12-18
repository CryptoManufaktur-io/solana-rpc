#!/bin/sh
find /home/sol/ledger -type f -name 'snapshot-*' -exec rm {} \;
docker run --rm \
-v /home/sol/ledger:/solana/snapshot \
--user $(id -u):$(id -g) \
c29r3/solana-snapshot-finder:latest \
--snapshot_path /solana/snapshot
exec solana-validator \
    --identity ~/validator-keypair.json \
    --no-voting \
    --ledger ~/ledger \
    --rpc-port 8899 \
    --dynamic-port-range 8000-8010 \
    --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
    --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
    --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
    --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
    --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record \
    --limit-ledger-size 100000000 \
    --log /mnt/sol-logs/validator.log \
    --accounts /mnt/sol-accounts/accounts \
    --account-index program-id spl-token-owner spl-token-mint \
    --no-snapshot-fetch \
    --enable-rpc-transaction-history \
    --no-port-check
