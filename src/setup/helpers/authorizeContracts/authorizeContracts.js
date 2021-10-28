const authorizeContracts = async (contracts, utils) => {
    const {
        owner,
        oracle,
        registrar,
        logger,
        manager,
        account,
    } = contracts

    const tx = {
        from: owner,
        gas: 7400000,
    }

    const oracleArg = utils.padRight(utils.toHex('oracle'), 64)
    await registrar.methods.addToRegistry(oracleArg, oracle.options.address).send(tx)
    console.log('oracle registered in registrar contract')

    await logger.methods.authorizeCreationManager(manager.options.address).send(tx)
    await account.methods.addSig(manager.options.address).send(tx)
    console.log('creation manager authorized for logger and multi-account')
}

export default authorizeContracts
