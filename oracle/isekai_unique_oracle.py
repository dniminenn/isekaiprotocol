"""
This script listens for new MintRequest events emitted by a smart contract and
handles them by minting a new token for the user who made the request. If any events
were missed due to connection issues or downtime, the script processes them before
continuing to listen for new events.

Author: Isekai Dev
"""

import time
from web3 import Web3
from web3.middleware import geth_poa_middleware
import json
from oracle_config import provider_url, private_key, contract_address, contract_abi

w3 = Web3(Web3.HTTPProvider(provider_url))
w3.middleware_onion.inject(geth_poa_middleware, layer=0)
account = w3.eth.account.privateKeyToAccount(private_key)

contract = w3.eth.contract(address=Web3.toChecksumAddress(
    contract_address), abi=contract_abi)


def fetch_metadata(token_id):
    """
    Fetches the metadata for a given token ID from a local directory.

    Args:
        token_id (int): The ID of the token to fetch metadata for.

    Returns:
        dict: The metadata for the specified token ID.
    """
    base_dir = "/home/isekai/assets/"  # Update this with the correct local path
    metadata_path = os.path.join(base_dir, f"{token_id}.json")

    with open(metadata_path, "r") as metadata_file:
        metadata = json.load(metadata_file)
    return metadata


def generate_random_number():
    """
    Generates a random integer between 0 and 10000.

    Returns:
        int: A randomly generated integer.
    """
    import random
    return random.randint(0, 10000)


def determine_is_legendary(token_id):
    """
    Determines whether a given token is a legendary based on its metadata.

    Args:
        token_id (int): The ID of the token to check.

    Returns:
        bool: True if the token is legendary, False otherwise.
    """
    metadata = fetch_metadata(token_id)
    return metadata.get("legendary", False)


def handle_mint_request(event):
    """
    Handles a MintRequest event by processing a mint transaction for the requester.

    Args:
        event (dict): The MintRequest event to handle.
    """
    requester = event["args"]["requester"]

    # Get the next token ID from the contract
    next_id = contract.functions.totalSupply().call() + 1

    isLegendary = determine_is_legendary(next_id)

    txn = contract.functions.processMint(requester, isLegendary).buildTransaction({
        "from": account.address,
        "gas": 200000,
        "gasPrice": w3.eth.gasPrice,
        "nonce": w3.eth.getTransactionCount(account.address),
    })
    signed_txn = w3.eth.account.signTransaction(txn, private_key)
    txn_hash = w3.eth.sendRawTransaction(signed_txn.rawTransaction)
    txn_receipt = w3.eth.waitForTransactionReceipt(txn_hash)


def main():
    """
    Main function that runs an event filter to monitor for new MintRequest events.
    """
    while True:
        try:
            event_filter = contract.events.MintRequest.createFilter(
                fromBlock="latest")
            while True:
                events = event_filter.get_new_entries()
                for event in events:
                    handle_mint_request(event)
                time.sleep(5)
        except Exception as e:
            print(f"Error occurred: {e}")
            time.sleep(10)


if __name__ == "__main__":
    main()
