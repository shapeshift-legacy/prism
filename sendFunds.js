const Web3 = require('web3')
const Redis = require('ioredis')
const web3 = new Web3('ws://localhost:8546')
const redis = new Redis({ host: 'localhost', port: 6379 })

const start = async () => {
    const accounts = await web3.eth.getAccounts()
    const address = await redis.get('prismcreationmanager.address')

    const obj = {
        from: accounts[1],
        to: address,
        gas: 6000000,
        value: web3.utils.toWei(process.argv[2])
    }

    await web3.eth.sendTransaction(obj)

    console.log('funds sent')
}

start()
    .then(() => { process.exit(0) })
    .catch(e => console.log(e.stack))
