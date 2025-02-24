<script lang="coffee">
import Records from '@/shared/services/records'
import EventBus from '@/shared/services/event_bus'
import Flash from '@/shared/services/flash'
import Session from '@/shared/services/session'
import { iconFor } from '@/shared/helpers/poll'
import { fieldFromTemplate } from '@/shared/helpers/poll'
import { map } from 'lodash'
import AppConfig from '@/shared/services/app_config'

export default
  props:
    discussion: Object
    close: Function

  data: ->
    poll: null
    shouldReset: false

  created: ->
    @init()

  computed:
    title_key: ->
      mode = if @poll.isNew()
        'start'
      else
        'edit'
      'poll_' + @poll.pollType + '_form.'+mode+'_header'

  methods:
    submit: ->
      @poll.customFields.can_respond_maybe = @poll.canRespondMaybe if @poll.pollType == 'meeting'
      @poll.setErrors({})
      @poll.save()
      .then (data) =>
        @init()
        @reset()
        pollKey = data.polls[0].key
        Records.polls.findOrFetchById(pollKey, {}, true).then (poll) =>
          EventBus.$emit 'pollSaved', poll
          Flash.success "poll_#{poll.pollType}_form.#{poll.pollType}_created"
          EventBus.$emit 'openModal',
            component: 'PollMembers',
            props:
              poll: poll
      .catch => true

    init: ->
      @poll = @newPoll()

    reset: ->
      @shouldReset = !@shouldReset

    newPoll: ->
      pollOptionNames = if AppConfig.features.app.proposal_consent_default
        ['consent', 'abstain', 'objection']
      else
        map fieldFromTemplate('proposal', 'poll_options_attributes'), 'name'

      Records.polls.build
        pollType: 'proposal'
        discussionId: @discussion.id
        groupId: @discussion.groupId
        pollOptionNames: pollOptionNames
        detailsFormat: Session.defaultFormat()

    icon: ->
      iconFor(@poll)

</script>
<template lang="pug">
.poll-proposal-complete-form.pa-3(@keyup.ctrl.enter="submit()" @keydown.meta.enter.stop.capture="submit()")
  submit-overlay(:value="poll && poll.processing")
  v-card-title
    h1.headline(tabindex="-1" v-t="title_key")
    v-spacer
  poll-common-directive(:poll='poll', name='form' :should-reset="shouldReset")
  v-card-actions.poll-common-form-actions
    v-spacer
    v-btn.poll-common-form__submit(v-if="poll.closingAt" color="primary" @click='submit()' v-t="{path: 'poll_common_form.start_poll_type', args: {poll_type: poll.translatedPollType()}}")
    v-btn.poll-common-form__submit(v-if="!poll.closingAt" color="primary" @click='submit()' v-t="{path: 'poll_common_form.share_poll_type', args: {poll_type: poll.translatedPollType()}}")
</template>
