const mockWeb3 = jest.fn()

const mockRedis = jest.fn()

const authorizeContracts = jest.fn()
const cacheContracts = jest.fn()
const createAccounts = jest.fn(() => ['account1'])
const migrateContracts = jest.fn(() => ({}))

const mockHelpers = {
    authorizeContracts,
    cacheContracts,
    createAccounts,
    migrateContracts,
}

jest.mock('web3', () => mockWeb3)
jest.mock('ioredis', () => mockRedis)
jest.mock('./helpers', () => mockHelpers)

const setup = require('./setup').default

describe('setup', () => {
    it('sets up the contract environment', async () => {
        global.process.env.NODE_ENV = 'test'

        await setup()

        expect(cacheContracts).toHaveBeenCalled()
    })

    it('does not set up the contract environment in production', async () => {
        global.process.env.NODE_ENV = 'production'

        await setup()

        expect(createAccounts).not.toHaveBeenCalled()
    })
})
