import createAccounts from './createAccounts'

global.console = {
    log: jest.fn(),
}

const mockWeb3 = {
    eth: {
        getAccounts: jest.fn(() => []),
        sendTransaction: jest.fn(),
        personal: {
            newAccount: jest.fn(),
            unlockAccount: jest.fn(),
        }
    },
    utils: {
        toWei: jest.fn()
    }
}

describe('createAccounts', () => {
    it('creates new accounts', async () => {
        await createAccounts(mockWeb3)

        expect(mockWeb3.eth.personal.newAccount.mock.calls.length).toBe(10)
    })
})
