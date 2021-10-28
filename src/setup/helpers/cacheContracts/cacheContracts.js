const cacheContracts = async (redis, contracts, utils) => {
    const {
        seller,
        oracle,
        registrar,
        logger,
        manager,
    } = contracts

    await redis.pipeline([
        ['set', 'seller.address', utils.toChecksumAddress(seller)],
        ['set', 'oracle.address', utils.toChecksumAddress(oracle.options.address)],
        ['set', 'oracle.abi', JSON.stringify(oracle.options.jsonInterface)],
        ['set', 'registrar.address', utils.toChecksumAddress(registrar.options.address)],
        ['set', 'registrar.abi', JSON.stringify(registrar.options.jsonInterface)],
        ['set', 'logger.address', utils.toChecksumAddress(logger.options.address)],
        ['set', 'logger.abi', JSON.stringify(logger.options.jsonInterface)],
        ['set', 'prismcreationmanager.address', utils.toChecksumAddress(manager.options.address)],
        ['set', 'prismcreationmanager.abi', JSON.stringify(manager.options.jsonInterface)],
    ]).exec()

    console.log('addresses cached')
}

export default cacheContracts
