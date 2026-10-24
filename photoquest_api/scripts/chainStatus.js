// Cek konfigurasi blockchain tanpa mengirim transaksi.
//   npm run chain:status
// Menampilkan wallet relayer, saldo, alamat kontrak, pemilik kontrak, dan jumlah catatan.
// Private key dan URL RPC tidak pernah dicetak.
require('dotenv').config({ quiet: true });
const { JsonRpcProvider, Wallet, Contract, formatEther, isAddress } = require('ethers');

const abi = require('../contracts/ChallengeRegistry.abi.json');

const PUBLIC_RPC = 'https://ethereum-sepolia-rpc.publicnode.com';

async function main() {
  const rpcSet = Boolean(process.env.SEPOLIA_RPC_URL);
  const key = (process.env.ETH_PRIVATE_KEY || '').trim();
  const address = (process.env.CHAIN_CONTRACT_ADDRESS || '').trim();
  console.log(`SEPOLIA_RPC_URL        : ${rpcSet ? 'terisi' : 'KOSONG (cek memakai RPC publik; backend butuh nilai ini)'}`);
  console.log(`ETH_PRIVATE_KEY        : ${key ? 'terisi' : 'KOSONG'}`);
  console.log(`CHAIN_CONTRACT_ADDRESS : ${address || 'KOSONG'}`);

  const provider = new JsonRpcProvider(process.env.SEPOLIA_RPC_URL || PUBLIC_RPC);
  const { chainId } = await provider.getNetwork();
  console.log(`Jaringan RPC           : chainId ${chainId}${chainId === 11155111n ? ' (Sepolia) OK' : ' BUKAN Sepolia'}`);

  let walletAddress = null;
  if (key) {
    try {
      walletAddress = new Wallet(key).address;
      console.log(`Wallet relayer         : ${walletAddress}`);
      console.log(`Saldo                  : ${formatEther(await provider.getBalance(walletAddress))} ETH`);
    } catch (_) {
      console.log('Wallet relayer         : ETH_PRIVATE_KEY TIDAK VALID');
    }
  }

  if (address) {
    if (!isAddress(address)) {
      console.log('Kontrak                : alamat tidak valid');
      return;
    }
    const code = await provider.getCode(address);
    if (code === '0x') {
      console.log('Kontrak                : TIDAK ADA kontrak di alamat ini (salah alamat / jaringan?)');
      return;
    }
    const c = new Contract(address, abi, provider);
    const owner = await c.owner();
    console.log(`Pemilik kontrak        : ${owner}`);
    console.log(`Jumlah catatan         : ${await c.recordCount()}`);
    if (walletAddress) {
      console.log(
        owner.toLowerCase() === walletAddress.toLowerCase()
          ? 'Relayer = pemilik      : YA (backend boleh menulis)'
          : 'Relayer = pemilik      : TIDAK (pakai private key wallet yang men-deploy)'
      );
    }
  }
}

main().catch((err) => {
  const msg = String(err.shortMessage || err.message || err).replace(/https?:\/\/\S+/g, '[url]');
  console.error(`\nGagal: ${msg}`);
  process.exitCode = 1;
});
