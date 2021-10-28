import { migrate, init } from 'scs'

const migrateContracts = async (web3, accounts) => {
    const context = await init(web3, { load: true, logging: true })
    const tx = {
        from: accounts[0],
        gas: 6000000,
    }

    const oracle = await migrate(context, 'CerberusOracle', null, tx)
    const registrar = await migrate(context, 'Registrar', null, tx)
    const logger = await migrate(context, 'PrismLogger', null, tx)
    const proxyFactory = await migrate(context, 'ProxyFactory', null, tx)
    const prism = await migrate(context, 'Prism', null, tx)
    const proxy = await migrate(context, 'Proxy', null, tx)

    const factoryArgs = [proxyFactory.options.address, prism.options.address, proxy.options.address]
    const factory = await migrate(context, 'PrismFactory', factoryArgs, tx)
    const account = await migrate(context, 'MultiAccount', null, tx)

    const managerArgs = [
        logger.options.address,
        factory.options.address,
        account.options.address,
        accounts[0],
        accounts[0],
        0,
    ]

    const manager = await migrate(context, 'PrismCreationManager', managerArgs, tx)

    return { oracle, registrar, logger, account, manager }
}

export default migrateContracts
