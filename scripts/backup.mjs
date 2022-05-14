#!/usr/bin/env zx

import { paths } from '../paths.mjs'
import nodePath from 'path'
const { TEST_RUN } = process.env

const getBackupDate = () => new Date()
  .toISOString()
  .replace(/T.*/, '')

TEST_RUN && console.log('\n========== TEST RUN ========== \n')

Object
  .entries(paths)
  .forEach(async ([ name, pathArr ]) => {
    const destination = nodePath.resolve(__dirname, `../${name}`)
    if (await $`test -d ${destination}`.exitCode !== 0) {
      console.log(`Making directory ${destination}`)
      !TEST_RUN && await $`mkdir -p ${destination}`
    }

    await Promise.all(
      pathArr.map(async path => {
        const source = path.replace('~', os.homedir())
        console.log(`Copying ${source} to ${destination}`)
        !TEST_RUN && await $`cp -rf ${source} ${destination}`
      })
    )
  })

if (!TEST_RUN) {
  await $`git add *`
  await $`git commit -m "Dotfiles Backup @${getBackupDate()}"`
}
