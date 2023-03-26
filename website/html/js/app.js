const body = document.querySelector('body');
const connectButtonContainer = document.getElementById('connect-button-container');
const connectButton = document.getElementById('connect-button');

// Initialize the Web3 instance
const web3 = new Web3(window.ethereum);

// Create the contract instance
// Replace ABI and season number (maybe load from dropdown?)
const seasonnft = new web3.eth.Contract(season0_abi, season0_addr);

// Check if the user is connected to Polygon
async function checkPolygonConnection() {
  if (typeof window.ethereum !== 'undefined') {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    if (chainId === '0x89') { // 0x89 is the chain ID for Polygon
      body.classList.remove('blur');
      connectButtonContainer.style.display = 'none';
    } else {
      body.classList.add('blur');
      connectButtonContainer.style.display = 'block';
    }
  }
}

// Connect to Polygon using MetaMask
async function connectToPolygon() {
  try {
    await window.ethereum.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: '0x89' }] });
  } catch (error) {
    console.error(error);
  }
}

// Add a click event listener to the "Connect" button
connectButton.addEventListener('click', connectToPolygon);

// Run the initial check
checkPolygonConnection();

// Listen for the chain change event
window.ethereum.on('chainChanged', checkPolygonConnection);

// Request mint with crystals
async function requestMintWithCrystals(amount) {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
  const account = accounts[0];
  await seasonnft.methods.requestMintCrystals(amount).send({ from: account });
}

// Add event listener for mint with crystals
const mintWithCrystalsButton = document.getElementById('mint-with-crystals-button');
mintWithCrystalsButton.addEventListener('click', async () => {
  const amount = 1; // Replace with the desired amount
  await requestMintWithCrystals(amount);
});

// Listen for MintProcessed events
seasonnft.events.MintProcessed({}, (error, event) => {
  if (error) {
    console.error('Error in event:', error);
  } else {
    const { user, tokenIds, nonce } = event.returnValues;
    console.log(`Mint processed for user ${user} with tokenIds ${tokenIds} and nonce ${nonce}`);
    // Update the UI based on the new tokens
  }
});
