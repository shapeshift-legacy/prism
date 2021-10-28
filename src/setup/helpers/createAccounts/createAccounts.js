const createAccounts = async (web3) => {
    const maxAccounts = 10

    const accounts = await web3.eth.getAccounts()

    for (let i = accounts.length; i < maxAccounts; i++) {
        const newAccount = await web3.eth.personal.newAccount('')
        console.log(`Created account: ${newAccount}`)
        await web3.eth.sendTransaction({
            from: accounts[0],
            to: newAccount,
            value: web3.utils.toWei('1000'),
        })
        console.log(`Funded account: ${newAccount}`)
        await web3.eth.personal.unlockAccount(newAccount, '', 0)
        console.log(`Unlocked account: ${newAccount}`)
    }

    return web3.eth.getAccounts()
}

export default createAccounts
