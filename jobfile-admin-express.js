const _ = require('lodash')

const dbUrl = process.env.DB_URL || 'mongodb://127.0.0.1:27017/atlas'

module.exports = {
  id: 'admin-express',
  store: 'fs',
  options: {
    workersLimit: 1
  },
  hooks: {
    tasks: {
      after: {
        clearData: {}
      }
    },
    jobs: {
      before: {
        createStores: [{
          id: 'memory'
        }, {
          id: 'fs',
          options: {
            path: __dirname
          }
        }],
        connectMongo: {
          url: dbUrl,
          // Required so that client is forwarded from job to tasks
          clientPath: 'taskTemplate.client'
        },
        runCommand: {
          commnand: 'bash admin-express.sh'
        }
      },
      after: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['memory', 'fs']
      },
      error: {
        disconnectMongo: {
          clientPath: 'taskTemplate.client'
        },
        removeStores: ['memory', 'fs']
      }
    }
  }
}
