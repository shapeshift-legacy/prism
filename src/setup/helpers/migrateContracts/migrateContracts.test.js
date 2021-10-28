const contract = {
    options: {
        address: '0xaddress',
    }
}

const migrate = jest.fn(() => contract)
const init = jest.fn()

const mockScs = {
    migrate,
    init,
}

jest.mock('scs', () => mockScs)

const migrateContracts = require('./migrateContracts').default

describe('migrateContracts', () => {
    it('migrates contracts', async () => {
        await migrateContracts({}, ['account'])

        expect(migrate.mock.calls.length).toBe(9)
    })
})
