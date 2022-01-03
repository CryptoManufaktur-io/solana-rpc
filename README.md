# solana-rpc

Solana RPC only node with traefik

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
sudo ufw allow proto tcp from 172.16.0.0/12 to any port 8899
sudo ufw allow proto tcp from 172.16.0.0/12 to any port 8900
sudo ufw allow proto tcp from 192.168.0.0/16 to any port 8899
sudo ufw allow proto tcp from 192.168.0.0/16 to any port 8900
sudo ufw allow proto tcp from 10.0.0.0/8 to any port 8899
sudo ufw allow proto tcp from 10.0.0.0/8 to any port 8900
sudo ufw allow proto tcp from SOURCEIP1 to any port 443 
sudo ufw allow proto tcp from SOURCEIP2 to any port 443 
sudo ufw deny proto tcp from any to any port 443 
sudo ufw enable
```

## HAProxy

`sol-haproxy.cfg` is an example configuration file for haproxy. It assumes that haproxy has `ca-certificates` available, see `haproxy.yml` for a sample setup.

# Setting up Solana

## Resources

The [official Solana docs](https://docs.solana.com/running-validator) and the [devnet notes](https://github.com/agjell/sol-tutorials/blob/master/setting-up-a-solana-devnet-validator.md) are both helpful.
The following is an opiniated amalgam of both, for Solana mainnet.

# Hardware

Dedicated / baremetal, Solana will run in systemd, not docker.

- 16 core/32 thread CPU that can boost above 3GHz, for example OVH Advance-4 (current-gen) with Epyc 7313 or webnx EPYC 7443
- 512 GiB (or better) of physical RAM
- 1TB (or better) of NVMe disk
- Avoid hardware RAID unless it's 9400/9500 tri mode series, e.g. Dell PERC11. You need TRIM commands to get through to the NVMe

## Linux prep
### Linux tuning

Ubuntu 20.04 LTS, because that's the supported distribution.

`sudo nano /etc/fstab` and add `,noatime` to options of `/`. Also comment out current swap entries, we'll create a new one.

`sudo nano /etc/default/grub` and add `mitigations=off` to `GRUB_CMDLINE_LINUX`. We can do this because it's bare metal. Then `sudo update-grub`.

Consider setting up [unattended-upgrades](https://haydenjames.io/how-to-enable-unattended-upgrades-on-ubuntu-debian/) as well. You can use [ssmtp](https://www.havetheknowhow.com/Configure-the-server/Install-ssmtp.html) to email you in case of failure.

### Set up user, create RAM disks and swap

Add a service user for Solana:

```
sudo adduser sol
sudo usermod -aG docker sol
```

Create two RAM disks for accounts, logs:

```
sudo mkdir /mnt/sol-accounts && sudo mkdir /mnt/sol-logs
echo 'tmpfs /mnt/sol-accounts tmpfs rw,noexec,nodev,nosuid,noatime,size=512G,user=sol 0 0' | \
  sudo tee --append /etc/fstab > /dev/null
echo 'tmpfs /mnt/sol-logs tmpfs rw,noexec,nodev,nosuid,noatime,size=56G,user=sol 0 0' | \
  sudo tee --append /etc/fstab > /dev/null
sudo mount --all --verbose
```

Add swap:

```
sudo swapoff -a
sudo dd if=/dev/zero of=/swapfile bs=1M count=256K
sudo chmod 600 /swapfile
sudo mkswap /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee --append /etc/fstab > /dev/null
echo 'vm.swappiness=0' | sudo tee --append /etc/sysctl.conf > /dev/null
sudo sysctl --load
```

Accounts will take maybe 60GB under normal circumstances. The swap is there so that
it can grow to 512 GB if necessary. You should alert on swap size and restart
Solana if it starts getting used, which will clear out accounts.

### Set up log rotation

To keep the log ramdisk from filling up

`sudo nano /etc/logrotate.d/solana`

and paste the following inside it.

```
/mnt/sol-logs/validator.log {
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

Do this as user `sol`, so `sudo su - sol` and then `sh -c "$(curl -sSfL https://release.solana.com/v1.8.11/install)"`

Paste this into `nano .profile` and then `source .profile`.

```
export PATH="/home/sol/.local/share/solana/install/active_release/bin:$PATH"
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
    --dynamic-port-range 8002-8012 \
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
    --log /mnt/sol-logs/validator.log \
    --accounts /mnt/sol-accounts/accounts \
    --account-index program-id spl-token-owner spl-token-mint \
    --account-index-exclude-key kinXdEcpDQeHPEuQnqmUgtYykqKGVFq6CeVX5iAHJq6 \
    --account-index-exclude-key TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
    --only-known-rpc \
    --enable-rpc-transaction-history \
    --no-port-check
```

Then `chmod +x ~/start-validator.sh`

This works around a current issue on mainnet beta with getting snapshots from official sources.
If that's resolved, you could replace `--no-snapshot-fetch` with `--only-known-rpc` and
remove the `docker run` command entirely.

`--no-port-check` allows us to a) make RPC available to traefik and b) firewall it off from the world.
`--no-voting` makes this RPC only, and keeps us from having to pay 1 to 1.1 SOL/day in fees.
`--enable-rpc-transaction-history` is necessary for websocket subscriptions to work.

Accounts, logs and snapshots are in ram disks.

### Set up systemd service files

Come back out of the sol user so you're on a user with root privileges again: `exit`

Create a service for the Solana validator service.

You can use the `validator.service` from this repo or `sudo nano /etc/systemd/system/validator.service` and paste

```
[Unit]
Description=Solana Validator
After=network.target
Wants=systuner.service
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=on-failure
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

Create the system tuning service it requires.

You can use the `systuner.service` from this repo or `sudo nano /etc/systemd/system/systuner.service` and paste

```
[Unit]
Description=Solana System Tuner
After=network.target

[Service]
Type=simple
Restart=on-failure
RestartSec=1
LogRateLimitIntervalSec=0
ExecStart=/home/sol/.local/share/solana/install/active_release/bin/solana-sys-tuner --user sol

[Install]
WantedBy=multi-user.target
```

### Enable and start system services

```
sudo systemctl enable --now systuner.service
sudo systemctl enable --now validator.service
```

Check their status:

```
sudo systemctl status systuner.service
```

```
sudo systemctl status validator.service
```

Resolve any issues

### Check that validator is running, useful commands

`sudo su - sol` to become user `sol` again

`docker ps` and then `docker logs -f CONTAINERNAME` to see the snapshot downloading.

Once that's finished:

`tail -f /mnt/sol-logs/validator.log` to see the logs of the Solana node

`solana-validator monitor` to monitor it

`solana catchup --our-localhost` to see how far it is from chain head.

It is normal for Solana to take ~30 minutes to catch up after a fresh start.

`grep --extended-regexp 'ERROR|WARN' /mnt/sol-logs/validator.log` to see error and warn logs.

`solana epoch-info` to get information about the epoch.

`df -h` to see fill status of ram disks.

`htop` to see CPU and memory use.

`sudo iostat -mdx` as a root-capable user to see NVMe utilization, of interest are `r_await` and `w_await`.

`solana-install init x.y.z` to pull a new version of Solana.

