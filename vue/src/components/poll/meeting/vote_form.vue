<script lang="coffee">
import EventBus from '@/shared/services/event_bus'
import Records from '@/shared/services/records'
import Session from '@/shared/services/session'
import Flash   from '@/shared/services/flash'
import {compact, map, toPairs, fromPairs, some, sortBy, isEqual} from 'lodash'

export default
  props:
    stance: Object

  data: ->
    stanceChoices: []
    pollOptions: []
    zone: null
    canRespondMaybe: null
    stanceValues: []

  beforeDestroy: ->
    EventBus.$off 'timeZoneSelected', @setTimeZone

  created: ->
    EventBus.$on 'timeZoneSelected', @setTimeZone
    @watchRecords
      collections: ['pollOptions']
      query: (records) =>
        @canRespondMaybe =  @stance.poll().customFields.can_respond_maybe
        @stanceValues = if @stance.poll().customFields.can_respond_maybe then [2,1,0] else [2, 0]
        if @stance.poll().optionsDiffer(@pollOptions)
          @pollOptions = @stance.poll().pollOptionsForVoting()
          @stanceChoices = @pollOptions.map (option) =>
            pollOption: option
            poll_option_id: option.id
            score: @stance.scoreFor(option)

  methods:
    setTimeZone: (e, zone) ->
      @zone = zone

    submit: ->
      @stance.stanceChoicesAttributes = @stanceChoices.map (choice) ->
        {poll_option_id: choice.poll_option_id, score: choice.score}

      actionName = if !@stance.castAt then 'created' else 'updated'
      @stance.save()
      .then =>
        EventBus.$emit "closeModal"
        Flash.success "poll_#{@stance.poll().pollType}_vote_form.stance_#{actionName}"
      .catch => true

    buttonStyleFor: (choice, score) ->
      if choice.score == score
        {opacity: 1}
      else
        {opacity: 0.3}

    imgForScore: (score) ->
      name = switch score
        when 2 then 'agree'
        when 1 then 'abstain'
        when 0 then 'disagree'
      "/img/#{name}.svg"

    incrementScore: (choice) ->
      if @canRespondMaybe
        choice.score = (choice.score + 5) % 3
      else
        choice.score = if choice.score == 2
          0
        else
          2

  computed:
    currentUserTimeZone: ->
      Session.user().timeZone

    reasonTooLong: ->
      @stance.reason && @stance.reason.length > 500 && !@stance.poll().allowLongReason

</script>

<template lang='pug'>
form.poll-meeting-vote-form(@submit.prevent='submit()')
  p.text--secondary(v-t="{path: 'poll_meeting_vote_form.local_time_zone', args: {zone: currentUserTimeZone}}")
  .poll-common-vote-form__options
    //- h3.lmo-h3.poll-meeting-vote-form--box(v-t="'poll_meeting_vote_form.can_attend'")
    //- h3.lmo-h3.poll-meeting-vote-form--box(v-t="'poll_meeting_vote_form.if_need_be'", v-if='canRespondMaybe')
    //- h3.lmo-h3.poll-meeting-vote-form--box(v-t="'poll_meeting_vote_form.unable'")
    //- time-zone-select.lmo-margin-left
    v-layout.poll-common-vote-form__option(wrap v-for='choice in stanceChoices' :key='choice.id')
      poll-common-stance-choice(:poll="stance.poll()" :stance-choice='choice' :zone='zone' @click="incrementScore(choice)")
      v-spacer
      v-btn.poll-meeting-vote-form--box(icon :style="buttonStyleFor(choice, i)" v-for='i in stanceValues', :key='i', @click='choice.score = i')
        v-avatar(:size="36")
          img.poll-common-form__icon(:src="imgForScore(i)")
  validation-errors(:subject='stance', field='stanceChoices')
  poll-common-add-option-button(:poll='stance.poll()')
  poll-common-stance-reason(:stance='stance')
  v-card-actions.poll-common-form-actions
    v-spacer
    v-btn.poll-common-vote-form__submit(color="primary" type='submit' :loading="stance.processing")
      span(v-t="stance.castAt? 'poll_common.update_vote' : 'poll_common.submit_vote'")
</template>
