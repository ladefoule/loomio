<script lang="coffee">
import Records from '@/shared/services/records'
import { fieldFromTemplate, myLastStanceFor } from '@/shared/helpers/poll'
import { max, values, orderBy, compact } from 'lodash'

export default
  props:
    options: Array

</script>

<template lang="pug">
.poll-common-chart-bar
  div.d-flex.rounded
    div.rounded.text-truncate.pa-2(
      v-for="option in options"
      :key="option.id"
      :style="{width: option.rawScorePercent()+'%', 'background-color': option.color}"
    )
      span {{option.optionName()}} {{option.scorePercent()}}%
</template>
<style lang="sass">

</style>
