<script lang="coffee">
import PollService    from '@/shared/services/poll_service'
import AbilityService from '@/shared/services/ability_service'
import EventBus       from '@/shared/services/event_bus'
import EventService from '@/shared/services/event_service'
import { pick, assign } from 'lodash'

export default
  components:
    ThreadItem: -> import('@/components/thread/item.vue')

  props:
    event: Object
    isReturning: Boolean

  created: ->
    EventBus.$on 'stanceSaved', => EventBus.$emit 'refreshStance'
    @watchRecords
      collections: ["stances", "outcomes", "polls"]
      query: (records) =>
        @myStance = @poll.myStance()
        @outcome = @poll.outcome()
        @showResults = @poll.showResults()

  beforeDestroy: ->
    EventBus.$off 'showResults'
    EventBus.$off 'stanceSaved'

  data: ->
    buttonPressed: false
    myStance: null
    outcome: null
    showResults: false

  computed:
    eventable: -> @event.model()
    poll: -> @eventable

    menuActions: ->
      assign(
        pick PollService.actions(@poll, @), ['edit_poll', 'close_poll', 'reopen_poll', 'notification_history', 'show_history', 'export_poll', 'print_poll', 'discard_poll', 'add_poll_to_thread']
      ,
        pick EventService.actions(@event, @), ['move_event', 'copy_url', 'pin_event', 'unpin_event']
      )
    dockActions: ->
      pick PollService.actions(@poll, @), ['show_results', 'hide_results', 'translate_poll', 'edit_stance', 'announce_poll', 'remind_poll']

</script>

<template lang="pug">
thread-item.poll-created(:event="event" :is-returning="isReturning")
  v-layout(justify-space-between)
    h1.poll-common-card__title.headline(tabindex="-1")
      poll-common-type-icon.mr-2(:poll="poll")
      router-link(:to="urlFor(poll)" v-if='!poll.translation.title') {{poll.title}}
      translation(v-if="poll.translation.title" :model='poll', field='title')
      tags-display(:tags="poll.tags()")
  .text--secondary
    poll-common-closing-at(:poll='poll')
  poll-common-set-outcome-panel(:poll='poll' v-if="!outcome")
  poll-common-outcome-panel(:outcome='outcome' v-if='outcome')
  formatted-text.poll-common-details-panel__details(:model="poll" column="details")
  link-previews(:model="poll")
  attachment-list(:attachments="poll.attachments")
  document-list(:model='poll')
  //- p.caption(v-if="!poll.pollOptionNames.length" v-t="'poll_common.no_voting'")
  div.body-2(v-if="poll.pollOptionNames.length")
    .poll-common-card__results-shown(v-if='showResults')
      poll-common-chart-panel(:poll="poll")
    poll-common-action-panel(:poll='poll')
  template(v-slot:actions)
    action-dock.my-2(small :actions="dockActions" :menu-actions="menuActions")
  template(v-if="!poll.stancesInDiscussion && poll.showResults()" v-slot:afterActions)
    poll-common-votes-panel(:poll="poll")
</template>
