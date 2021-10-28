const { basename } = require('path')

module.exports = {
    apps: [
        {
            name: basename(__dirname),
            script: 'private/server.js',
        },
    ],
    watch: ['dist', 'private']
}
