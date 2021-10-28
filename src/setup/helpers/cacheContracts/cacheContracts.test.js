import cacheContracts from './cacheContracts'

global.JSON = {
    stringify: jest.fn(),
}

global.console = {
    log: jest.fn(),
}

const exec = jest.fn()
const mockRedis = {
    pipeline: jest.fn(() => ({ exec }))
}

const contract = {
    options: {
        address: '0xaddress',
        jsonInterface: 'interface',
    }
}
const mockContracts = {
    seller: '0xseller',
    oracle: contract,
    registrar: contract,
    logger: contract,
    manager: contract,
}

const mockUtils = {
    toChecksumAddress: jest.fn(),
}

describe('cacheContracts', () => {
    it('caches contracts', async () => {
        await cacheContracts(mockRedis, mockContracts, mockUtils)

        expect(exec).toHaveBeenCalled()
    })
})
