import authorizeContracts from './authorizeContracts'

global.console = {
    log: jest.fn(),
}

const oracle = {
    options: {
        address: '0xoracle',
    }
}

const registrar = {
    methods: {
        addToRegistry: jest.fn(() => ({
            send: jest.fn(),
        }))
    }
}

const logger = {
    methods: {
        authorizeCreationManager: jest.fn(() => ({
            send: jest.fn(),
        }))
    }
}

const manager = {
    options: {
        address: '0xmanager',
    }
}

const account = {
    methods: {
        addSig: jest.fn(() => ({
            send: jest.fn(),
        }))
    }
}

const mockContracts = {
    owner: '0xowner',
    oracle,
    registrar,
    logger,
    manager,
    account,
}

const mockUtils = {
    padRight: jest.fn(),
    toHex: jest.fn(),
}

describe('authorizeContracts', () => {
    it('is successful', async () => {
        await authorizeContracts(mockContracts, mockUtils)

        expect(account.methods.addSig).toHaveBeenCalled()
    })
})
