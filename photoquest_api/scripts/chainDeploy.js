// Deploy smart contract ChallengeRegistry ke Ethereum Sepolia dari laptop (alternatif Remix).
//   npm run chain:deploy
// Membaca dari photoquest_api/.env:
//   ETH_PRIVATE_KEY  (wajib, wallet KHUSUS testnet; wallet ini menjadi pemilik kontrak)
//   SEPOLIA_RPC_URL  (opsional; bila kosong memakai RPC publik)
// Private key dan URL RPC tidak pernah dicetak.
require('dotenv').config({ quiet: true });
const { JsonRpcProvider, Wallet, ContractFactory, formatEther } = require('ethers');

const abi = require('../contracts/ChallengeRegistry.abi.json');
const { bytecode } = require('../contracts/ChallengeRegistry.bytecode.json');

const PUBLIC_RPC = 'https://ethereum-sepolia-rpc.publicnode.com';
const SEPOLIA_CHAIN_ID = 11155111n;

async function main() {
  const key = (process.env.ETH_PRIVATE_KEY || '').trim();
  if (!key) {
    throw new Error('ETH_PRIVATE_KEY belum diisi di photoquest_api/.env (lihat BLOCKCHAIN_SETUP.md bagian 5)');
  }
  const provider = new JsonRpcProvider(process.env.SEPOLIA_RPC_URL || PUBLIC_RPC);
  const network = await provider.getNetwork();
  if (network.chainId !== SEPOLIA_CHAIN_ID) {
    throw new Error(`RPC bukan Sepolia (chainId ${network.chainId}). Deploy dibatalkan.`);
  }

  let wallet;
  try {
    wallet = new Wallet(key, provider);
  } catch (_) {
    throw new Error('ETH_PRIVATE_KEY tidak valid (harus 64 karakter hex, boleh diawali 0x)');
  }
  const balance = await provider.getBalance(wallet.address);
  console.log(`Wallet pemilik : ${wallet.address}`);
  console.log(`Saldo          : ${formatEther(balance)} ETH (Sepolia)`);
  if (balance === 0n) throw new Error('Saldo 0. Ambil ETH Sepolia dari faucet dulu.');

  console.log('Mengirim transaksi deploy... (biasanya 10-30 detik)');
  const contract = await new ContractFactory(abi, bytecode, wallet).deploy();
  const tx = contract.deploymentTransaction();
  console.log(`Tx deploy      : https://sepolia.etherscan.io/tx/${tx.hash}`);
  const receipt = await tx.wait();
  const address = await contract.getAddress();

  console.log('');
  console.log('BERHASIL');
  console.log(`Alamat kontrak : ${address}`);
  console.log(`Blok           : ${receipt.blockNumber}`);
  console.log(`Pemilik        : ${await contract.owner()}`);
  console.log(`Etherscan      : https://sepolia.etherscan.io/address/${address}`);
  console.log('');
  console.log('Langkah berikutnya: isi di photoquest_api/.env (dan Environment Render):');
  console.log(`  CHAIN_CONTRACT_ADDRESS=${address}`);
}

main().catch((err) => {
  // Hanya pesan singkat; jangan pernah mencetak kunci.
  const msg = String(err.shortMessage || err.message || err).replace(/https?:\/\/\S+/g, '[url]');
  console.error(`\nGagal: ${msg}`);
  process.exitCode = 1;
});
