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
job.hooks.tasks.after = hooks.insertHookAfter('clearData', job.hooks.tasks.after, 'mbtiles', {
  hook: 'runCommand',
  command: `tippecanoe -o osm-boundaries/osm-boundaries.mbtiles -Llevel2:<(cat osm-boundaries/2/*-boundaries.geojson) -Llevel3:<(cat osm-boundaries/3/*-boundaries.geojson) -Llevel4:<(cat osm-boundaries/4/*-boundaries.geojson)\
    -Llevel5:<(cat osm-boundaries/5/*-boundaries.geojson) -Llevel6:<(cat osm-boundaries/6/*-boundaries.geojson) -Llevel7:<(cat osm-boundaries/7/*-boundaries.geojson) -Llevel8:<(cat osm-boundaries/8/*-boundaries.geojson)\
    -Llevel2toponyms:<(cat osm-boundaries/2/*-toponyms.geojson) -Llevel3toponyms:<(cat osm-boundaries/3/*-toponyms.geojson) -Llevel4toponyms:<(cat osm-boundaries/4/*-toponyms.geojson)\
    -Llevel5toponyms:<(cat osm-boundaries/5/*-toponyms.geojson) -Llevel6toponyms:<(cat osm-boundaries/6/*-toponyms.geojson) -Llevel7toponyms:<(cat osm-boundaries/7/*-toponyms.geojson) -Llevel8toponyms:<(cat osm-boundaries/8/*-toponyms.geojson) -f --no-tile-size-limit`
})
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
