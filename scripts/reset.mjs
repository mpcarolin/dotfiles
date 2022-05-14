#!/usr/bin/env zx

import { paths } from '../paths.mjs'
import nodePath from 'path'
const { TEST_RUN } = process.env

TEST_RUN && console.log('\n========== TEST RUN ========== \n')

Object
  .keys(paths)
  .forEach(async directoryName => {
    const path = nodePath.resolve(__dirname, `../${directoryName}`)
    if (await $`test -d ${path}`.exitCode === 0) {
      console.log(`Deleting local git directory ${path}`)
      !TEST_RUN && await $`rm -rf ${path}`
    }
  })

