<script lang="coffee">
import { approximate, exact } from '@/shared/helpers/format_time'
import { parseISO } from 'date-fns'
import {isString} from 'lodash'

export default
  props:
    date: [Date, String]

  data: ->
    parsedDate: null

  created: ->
    if isString(@date)
      @parsedDate = parseISO(@date)
    else
      @parsedDate = @date

</script>

<template lang="pug">
abbr.time-ago.text--secondary(:title='exactDate(parsedDate)') {{approximateDate(parsedDate)}}
</template>

<style lang="sass">
.time-ago
  white-space: nowrap
abbr[title]
  text-decoration: none
  border-bottom: none

</style>
