const body = document.querySelector('body');
const connectButtonContainer = document.getElementById('connect-button-container');
const connectButton = document.getElementById('connect-button');

// Initialize the Web3 instance
const web3 = new Web3(window.ethereum);

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