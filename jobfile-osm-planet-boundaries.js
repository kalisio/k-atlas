import path from 'path'
import { hooks } from '@kalisio/krawler'
// Initialize base job
import job from './jobfile-osm-boundaries.js'

// Simplification tolerance, defaults to 128m at level 2 => 2m at level 8
const tolerance = process.env.SIMPLIFICATION_TOLERANCE ? Number(process.env.SIMPLIFICATION_TOLERANCE) : 128

// Avoid clearing DB as we come after main job
delete job.hooks.jobs.before.dropMongoCollection
// Avoid generating continent tasks
delete job.hooks.jobs.before.generateTasks
// Set single task
const basename = 'planet'
const level = 2
const id = `osm-boundaries/${basename}.pbf`
const key = `osm-boundaries/${level}/${basename}`
const dir = path.dirname(key)
let task = {
  id,
  key,
  dir,
  basename,
  level,
  type: 'http',
  // Skip download if file already exists
  overwrite: false,
  options: {
    url: 'https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf'
  }
}
if (tolerance) {
  // Full tolerance at level 2
  Object.assign(task, { tolerance })
}
job.tasks = [task]

export default job
