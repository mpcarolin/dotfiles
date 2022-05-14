#!/usr/bin/env zx

import { paths } from '../paths.mjs'
import nodePath from 'path'
const { TEST_RUN } = process.env

TEST_RUN && console.log('\n========== TEST RUN ========== \n')

const ensureDirs = async dest => {
  console.log('ensureDirs', dest)
  const dirName = nodePath.dirname(dest)
  if (await $`test -d ${dirName}`.exitCode !== 0) {
    console.log(`Creating all required directories for ${dirName}`)
    !TEST_RUN && await $`mkdir -p ${dirName}`
 }
}

Object
  .entries(paths)
  .forEach(async ([ name, pathArr ]) => {
    const sourceDir = nodePath.resolve(__dirname, `../${name}`)

    await Promise.all(
      pathArr.map(async path => {
        const fileName = nodePath.basename(path)
        const source = nodePath.resolve(sourceDir, fileName)
        const destination = path.replace('~', os.homedir())
        await ensureDirs(destination)
        console.log(`Copying ${source} to ${destination}`)
        !TEST_RUN && await $`cp -rf ${source} ${destination}`
      })
    )
  })

