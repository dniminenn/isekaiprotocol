use web3::{types::*, Web3, contract::{Contract, Options}};
use tokio;
use rand::{Rng, thread_rng};
use serde_json;
use hex;
use std::{env, time::Duration};

async fn generate_random_number() -> u32 {
    let mut rng = thread_rng();
    rng.gen_range(0..10000)
}

async fn determine_token_id(random_number: u32) -> u32 {
    let probabilities = [2300, 2300, 2300, 700, 700, 700, 300, 300, 300, 49, 49, 2];
    let mut current_sum = 0;

    for &probability in &probabilities {
        current_sum += probability;
        if random_number < current_sum {
            return probabilities.iter().position(|&x| x == probability).unwrap() as u32 + 1;
        }
    }
    return 1;
}

async fn determine_token_id_crystal(random_number: u32) -> u32 {
    let probabilities = [0, 0, 0, 2333, 2333, 2333, 833, 833, 833, 249, 249, 4];
    let mut current_sum = 0;

    for &probability in &probabilities {
        current_sum += probability;
        if random_number < current_sum {
            return probabilities.iter().position(|&x| x == probability).unwrap() as u32 + 1;
        }
    }
    return 1;
}

async fn handle_mint_request(event: Log, contract: &Contract<web3::transports::Http>) {
    let user = event.topics[1].into();
    let nonce = event.topics[2].into();
    let crystals = event.topics[3].into();
    let amount = event.data.0[0];
    let mut token_id_list = Vec::new();

    for _ in 0..amount {
        let random_number = generate_random_number().await;
        let token_id = if crystals == 1 {
            determine_token_id_crystal(random_number).await
        } else {
            determine_token_id(random_number).await
        };
        token_id_list.push(token_id);
    }

    let options = Options::default();
    let call_result = contract.call("mint", (user, token_id_list, nonce, Vec::<u8>::new()), None, options).await;
    println!("Call result: {:?}", call_result);
}

async fn process_missed_events(contract: &Contract<web3::transports::Http>) {
    let last_processed_nonce: U256 = contract.query("lastProcessedNonce", (), None, Options::default(), None).await.unwrap();
    let filter = FilterBuilder::default()
        .from_block(BlockNumber::Earliest)
        .to_block(BlockNumber::Latest)
        .address(vec![contract.address()])
        .topics(Some(vec![(*contract.events().get("MintRequest").unwrap().signature()).into()]), Some(vec![last_processed_nonce + 1]), None, None)
        .build();

    let logs = contract.web3().eth().logs(filter).await.unwrap();

    for event in logs {
        handle_mint_request(event, contract).await;
    }
}

#[tokio::main]
async fn main() {
    let provider_url = env::var("PROVIDER_URL").expect("Set PROVIDER_URL environment variable");
    let private_key = env::var("PRIVATE_KEY").expect("Set PRIVATE_KEY environment variable");
    let contract_address = env::var("CONTRACT_ADDRESS").expect("Set CONTRACT_ADDRESS environment variable");
    let contract_abi = env::var("CONTRACT_ABI").expect("Set CONTRACT_ABI environment variable");

    let http = web3::transports::Http::new(&provider_url).unwrap();
    let web3 = Web3::new(http);
    let address: Address = contract_address.parse().unwrap();
    let abi = serde_json::from_str(&contract_abi).unwrap();

    let contract = Contract::new(web3.eth(), address, abi);

    loop {
        println!("Isekai Oracle running, looking at past events");
        process_missed_events(&contract).await;

        let filter = FilterBuilder::default()
            .address(vec![contract.address()])
            .topics(Some(vec![(*contract.events().get("MintRequest").unwrap().signature()).into()]), None, None, None)
            .build();

        loop {
            println!("Treating incoming events");
            let logs = contract.web3().eth().logs(filter.clone()).await.unwrap();

            for event in logs {
                println!("Received event, processing...\n");
                handle_mint_request(event, &contract).await;
            }
            tokio::time::sleep(Duration::from_secs(5)).await;
        }
    }
}
