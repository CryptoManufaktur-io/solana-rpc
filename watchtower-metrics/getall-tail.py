import re
from prometheus_client import start_http_server, Gauge
import subprocess
from decimal import Decimal

# Prometheus metrics
current_transaction_count = Gauge('solana_current_transaction_count', 'Current transaction count')
current_validator_count = Gauge('solana_current_validator_count', 'Current validator count')
delinquent_validator_count = Gauge('solana_delinquent_validator_count', 'Delinquent validator count')
current_stake = Gauge('solana_current_stake', 'Current stake percentage')
total_stake = Gauge('solana_total_stake', 'Total stake')
current_stake_value = Gauge('solana_current_stake_value', 'Current stake value')
delinquent_stake = Gauge('solana_delinquent_stake', 'Delinquent stake')

# Log file path
log_file_path = '/app/watchtower.log'

def format_value(value):
    return Decimal(value)

# Function to parse log entries and update metrics
def parse_log_entry(entry):
    transaction_count_match = re.search(r'Current transaction count: (\d+)', entry)
    validator_count_match = re.search(r'Current validator count: (\d+)', entry)
    delinquent_count_match = re.search(r'Delinquent validator count: (\d+)', entry)
    stake_match = re.search(r'Current stake: (\d+\.\d+)% \| Total stake: (.*?), current stake: (.*?), delinquent: (.*?)$', entry)

    if transaction_count_match:
        current_transaction_count.set(int(transaction_count_match.group(1)))

    if validator_count_match:
        current_validator_count.set(int(validator_count_match.group(1)))

    if delinquent_count_match:
        delinquent_validator_count.set(int(delinquent_count_match.group(1)))

    if stake_match:
        current_stake.set(format_value(re.sub(r"[^\d\.]", "", stake_match.group(1))))
        total_stake.set(format_value(re.sub(r"[^\d\.]", "", stake_match.group(2))))
        current_stake_value.set(format_value(re.sub(r"[^\d\.]", "", stake_match.group(3))))
        delinquent_stake.set(format_value(re.sub(r"[^\d\.]", "", stake_match.group(4))))

# Function to continuously monitor the log file using tail
def tail_log_file():
    try:
        process = subprocess.Popen(["tail", "-n", "50", "-F", log_file_path], stdout=subprocess.PIPE)
        for line in iter(process.stdout.readline, ''):
            print(line)
            parse_log_entry(line.decode('utf-8'))
    except FileNotFoundError:
        print(f"Log file '{log_file_path}' not found. Please check the file path.")

# Start Prometheus server
start_http_server(8000)

# Parse log file on load
tail_log_file()
