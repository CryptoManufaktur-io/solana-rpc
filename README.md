# solana-rpc

Solana RPC only node with traefik. Solana runs in systemd, and traefik in Docker.

# Prerequisites

Docker, e.g.

`sudo apt update && sudo apt -y install docker.io docker-compose`

# Setting up Traefik

`cp default.env .env && cp traefik-dynamic.sample traefik-dynamic.toml`

Edit `.env` to choose CloudFlare or AWS as your DNS provider, and adjust API keys and
domain name. See [Reverse Proxy](https://eth-docker.net/docs/Usage/ReverseProxy) docs
for details.

Edit `traefik-dynamic.toml` to adjust the host name and domain name of your Solana node,
and the host IP of the host this traefik runs on and that Solana runs on.

And start it all with `docker-compose up -d`. Add `sudo` if your user isn't part of the
`docker` group.

## UFW considerations

Place ufw "in the path" of docker, see [instructions](https://eth-docker.net/docs/Support/Cloud).

What you'd typically want is that traefik can access the Solana RPC ports, but nothing else can;
and that traefik is only reachable by allow-listed IPs.

You can achieve this by something like this:

```
sudo ufw allow OpenSSH 
sudo ufw allow proto tcp from 172.16.0.0/12 to any port 8899 comment "Traefik to Solana RPC"
sudo ufw allow proto tcp from 172.16.0.0/12 to any port 8900 comment "Traefik to Solana WS"
sudo ufw allow proto tcp from 192.168.0.0/16 to any port 8899 comment "Traefik to Solana RPC"
sudo ufw allow proto tcp from 192.168.0.0/16 to any port 8900 comment "Traefik to Solana WS"
sudo ufw allow proto tcp from 10.0.0.0/8 to any port 8899 comment "Traefik to Solana RPC"
sudo ufw allow proto tcp from 10.0.0.0/8 to any port 8900 comment "Traefik to Solana WS"
sudo ufw allow 8001/tcp comment "Solana Gossip"
sudo ufw allow 8000:8020/udp comment "Solana QUIC"
sudo ufw allow proto tcp from SOURCEIP1 to any port 443 
sudo ufw allow proto tcp from SOURCEIP2 to any port 443 
sudo ufw deny proto tcp from any to any port 443 
sudo ufw enable
```

Note Solana will use UDP ports 8000-10000 locally, after receiving data on the QUIC TPU; but you only need to open the `--dynamic-port-range` to Internet.

## HAProxy

`sol-haproxy.cfg` is an example configuration file for haproxy. It assumes that haproxy has `ca-certificates` available, see `haproxy.yml` for a sample setup.

# Setting up Solana

## Resources

The [official Solana docs](https://docs.solana.com/running-validator) and the [devnet notes](https://github.com/agjell/sol-tutorials/blob/master/setting-up-a-solana-devnet-validator.md) are both helpful.
The following is an opiniated amalgam of both, for Solana mainnet.

# Hardware

Dedicated / baremetal, Solana will run in systemd, not docker.

- 16 or 24 core CPU that can boost above 3GHz, for example EPYC 7443p
- 1 TiB of physical RAM if [full indices](https://docs.solana.com/running-validator/validator-start#account-indexing) are desired
- 1TB (or better) of NVMe disk
- Avoid hardware RAID unless it's 9400/9500 tri mode series, e.g. Dell PERC11. You need TRIM commands to get through to the NVMe

## Linux prep
### Linux tuning

Ubuntu 20.04 or 22.04 LTS, because that's the supported distribution.

`sudo nano /etc/fstab` and add `,noatime` to options of `/`. Also comment out current swap entries, as you won't need swap.

`sudo nano /etc/default/grub` and add `mitigations=off` to `GRUB_CMDLINE_LINUX`. We can do this because it's bare metal. Then `sudo update-grub`.

Consider setting up [unattended-upgrades](https://haydenjames.io/how-to-enable-unattended-upgrades-on-ubuntu-debian/) as well. You can use [msmtp](https://caupo.ee/blog/2020/07/05/how-to-install-msmtp-to-debian-10-for-sending-emails-with-gmail/) to email you in case of failure.

### Set up user

Add a service user for Solana:

```
sudo adduser sol
sudo usermod -aG docker sol
```

### Set up log rotation

To keep the log disk from filling up

`sudo nano /etc/logrotate.d/solana`

and paste the following inside it.

```
/home/sol/validator.log {
  su sol sol
  daily
  rotate 7
  compress
  delaycompress
  missingok
  postrotate
    systemctl kill -s USR1 validator.service
  endscript
}
```

And then `sudo systemctl restart logrotate`

## Solana client
### Download client

Become user `sol`: `sudo su - sol`

Download and install Solana, replacing the version with the current one:

`export VERSION=v1.17.11`
`sh -c "$(curl -sSfL https://release.solana.com/${VERSION}/install)"`

Paste this to the end of `nano .profile` and then `source .profile`.

```
export SOLANA_METRICS_CONFIG="host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password"
```

### Set up for mainnet, generate account


Mainnet beta.

`solana config set --url https://api.mainnet-beta.solana.com`

Generate identity. We won't need wallet etc because we won't be validating. Keep the mnemonic / seed phrase securely offline.

`solana-keygen new --outfile ~/validator-keypair.json`

### Prep start command

You can use the `start-validator.sh` from this repo or `nano ~/start-validator.sh` and paste

```
#!/bin/sh
exec solana-validator \
    --identity ~/validator-keypair.json \
    --no-voting \
    --ledger ~/ledger \
    --rpc-port 8899 \
    --gossip-port 8001 \
    --dynamic-port-range 8000-8020 \
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
    --limit-ledger-size 50000000 \
    --log ~/validator.log \
    --account-index program-id spl-token-owner spl-token-mint \
    --account-index-exclude-key kinXdEcpDQeHPEuQnqmUgtYykqKGVFq6CeVX5iAHJq6 \
    --account-index-exclude-key TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
    --only-known-rpc \
    --enable-rpc-transaction-history \
    --full-rpc-api \
    --rpc-bind-address 0.0.0.0 \
    --private-rpc \
    --use-snapshot-archives-at-startup when-newest \
    --no-snapshot-fetch
```

Note the indices take a lot of RAM and are only needed for `getProgram` and `getToken` calls. With them, a 1 TiB RAM machine is recommended; without them, a 512 GiB RAM machine will suffice.

Then `chmod +x ~/start-validator.sh`

`--no-voting` makes this RPC only, and keeps us from having to pay 1 to 1.1 SOL/day in fees.
`--enable-rpc-transaction-history` is necessary for websocket subscriptions to work.

### Set up systemd service file

Come back out of the sol user so you're on a user with root privileges again: `exit`

Create a service for the Solana validator service.

You can use the `validator.service` from this repo or `sudo nano /etc/systemd/system/validator.service` and paste

```
[Unit]
Description=Solana Validator
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
LimitNOFILE=1000000
LogRateLimitIntervalSec=0
User=sol
Environment=PATH=/home/sol/.local/share/solana/install/active_release/bin:/usr/bin:/bin
Environment=SOLANA_METRICS_CONFIG=host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password
ExecStart=/home/sol/start-validator.sh

[Install]
WantedBy=multi-user.target
```

### Tune the system

Follow [the instructions](https://docs.solana.com/running-validator/validator-start#system-tuning), then log out and back in. Tuning is a required step.

### Grab initial snapshots

The validator is set to start without fetching snapshots, which speeds up startup and keeps it from hanging if an RPC server with highest snapshot isn't actually reachable.
Get snapshots manually, once, with `./solana-get-snapshots.sh`

### Enable and start system service

```
sudo systemctl enable --now validator.service
```

Check status:

```
sudo systemctl status validator.service
```

Resolve any issues

### Check that validator is running, useful commands

`./solana-update.sh` - helper script to update Solana, from the main system user that can sudo

`./solana-restart.sh` - helper script to safely restart Solana, from the main system user that can sudo

`./solana-get-snapshots.sh` - helper script to fetch snapshots from Solana Foundation, from the main system user that can sudo. This would only be used during cluster restarts.

`sudo su - sol` to become user `sol` again and run the below commands

`tail -f ~/validator.log` to see the logs of the Solana node

`solana-validator monitor` to monitor it

`solana catchup --our-localhost` to see how far it is from chain head.

It is normal for Solana to take ~20 minutes to catch up after a fresh start.

`grep --extended-regexp 'ERROR|WARN' ~/validator.log` to see error and warn logs.

`solana epoch-info` to get information about the epoch.

`solana validators` to get a list of validators, their stake %age and version.

`df -h` to see fill status of disks.

`htop` to see CPU and memory use.

`sudo iostat -mdx` as a root-capable user to see NVMe utilization, of interest are `r_await` and `w_await`.

`solana-install init x.y.z` to pull a new version of Solana.

`solana-validator exit -m` for a safe exit of the validator when it has a fresh snapshot and isn't scheduled to be leader

