import Web3 from 'web3'
import Redis from 'ioredis'

import {
    authorizeContracts,
    cacheContracts,
    createAccounts,
    migrateContracts,
} from './helpers'

// sets up contracts & web3 accounts in local development only
const setup = async () => {
    if (!/(production|staging)/i.test(process.env.NODE_ENV)) {
        const web3 = new Web3('ws://localhost:8546')
        const redis = new Redis({ host: 'localhost', port: 6379 })

        /* setup accounts
        */
        const accounts = await createAccounts(web3)

        /* migrate contracts
        */
        const contracts = await migrateContracts(web3, accounts)
        contracts.seller = accounts[0]
        contracts.owner = accounts[0]

        /* authorize contracts
        */
        await authorizeContracts(contracts, web3.utils)

        /* save to redis
        */
        await cacheContracts(redis, contracts, web3.utils)
    }
}

export default setup
