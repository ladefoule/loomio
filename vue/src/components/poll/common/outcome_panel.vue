<script lang="coffee">
import OutcomeService from '@/shared/services/outcome_service'
import parseISO from 'date-fns/parseISO'
export default
  props:
    outcome: Object
  methods:
    parseISO: parseISO
  computed:
    actions: -> OutcomeService.actions(@outcome, @)

</script>

<template lang="pug">
v-alert.my-4.poll-common-outcome-panel(
  v-if="outcome"
  color="primary lighten-2"
  colored-border
  border="left"
  elevation="3")
  .title(v-t="'poll_common.outcome'")
  .poll-common-outcome-panel__authored-by.caption.my-2
    span(v-t="{ path: 'poll_common_outcome_panel.authored_by', args: { name: outcome.authorName() } }")
    space
    time-ago(:date="outcome.createdAt")
    span(v-if="outcome.reviewOn")
      mid-dot
      span(v-t="'poll_common.review_due'")
      space
      time-ago(:date="outcome.reviewOn")
  .poll-common-outcome__event-info(v-if="outcome.poll().datesAsOptions() && outcome.pollOption()")
    .title {{outcome.eventSummary}}
    span {{exactDate(parseISO(outcome.pollOption().name))}}
    p {{outcome.eventLocation}}
  formatted-text(style="font-size: 15px" :model="outcome" column="statement")
  link-previews(:model="outcome")
  document-list(:model="outcome")
  attachment-list(:attachments="outcome.attachments")
  action-dock(small :model="outcome" :actions="actions")
</template>
