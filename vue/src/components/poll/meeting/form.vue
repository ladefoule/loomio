<script lang="coffee">
import AppConfig from '@/shared/services/app_config'
import EventBus  from '@/shared/services/event_bus'
import { addDays, addMinutes, intervalToDuration, formatDuration } from 'date-fns'
import { pull } from 'lodash'

export default
  props:
    poll: Object
    back: Boolean

  data: ->
    durations:
      [5, 10, 15, 20, 30, 45, 60, 90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240, null].map (minutes) =>
        if minutes
          duration = intervalToDuration({ start: new Date, end: addMinutes(new Date, minutes) })
          {text: formatDuration(duration, { format: ['hours', 'minutes'] }), value: minutes}
        else
          {text: @$t('common.all_day'), value: null}
    menu: false

  created: ->
    @poll.customFields.meeting_duration = @poll.customFields.meeting_duration or 60
    if @poll.isNew()
      @poll.canRespondMaybe = true
      @poll.closingAt = addDays(new Date, 3)
      @poll.notifyOnParticipate = true
    # EventBus.listen $scope, 'timeZoneSelected', (e, zone) ->
    #   $scope.poll.customFields.time_zone = zone
</script>

<template lang="pug">
.poll-meeting-form
  poll-common-form-fields(:poll="poll")
  poll-meeting-form-options-field(:poll="poll")
  v-select(v-model="poll.customFields.meeting_duration" :label="$t('poll_meeting_form.meeting_duration')" :items="durations")
  poll-common-closing-at-field(:poll="poll")
  poll-common-settings(:poll="poll")
  common-notify-fields(:model="poll")
</template>
