<script lang="coffee">
import Session        from '@/shared/services/session'
import StanceService        from '@/shared/services/stance_service'
import AbilityService from '@/shared/services/ability_service'
import openModal from '@/shared/helpers/open_modal'

export default
  components:
    ThreadItem: -> import('@/components/thread/item.vue')

  props:
    event: Object
    isReturning: Boolean
    collapsed: Boolean

  computed:
    eventable: -> @event.model()
    poll: -> @eventable.poll()
    showResults: -> @eventable.poll().showResults()
    actions: -> StanceService.actions(@eventable)

    componentType:  ->
      if @event.actor()
        'router-link'
      else
        'div'
</script>

<template lang="pug">

section.strand-item__stance-created.stance-created(id="'comment-'+ eventable.id" :event="event" :is-returning="isReturning")
  template(v-if="eventable.singleChoice()")
    .d-flex
      component(:is="componentType" :to="event.actor() && urlFor(event.actor())") {{event.actorName()}}
      space
      poll-common-stance-choice(v-if="showResults" :poll="poll" :stance-choice="eventable.stanceChoice()")
  .poll-common-stance(v-if="showResults && !collapsed")
    v-layout(v-if="!eventable.singleChoice()" wrap align-center)
      strand-item-headline(:event="event" :eventable="eventable")
      poll-common-stance-choices(:stance="eventable")
    formatted-text.poll-common-stance-created__reason(:model="eventable" column="reason")
    link-previews(:model="eventable")
    attachment-list(:attachments="eventable.attachments")
  action-dock(:model='eventable' :actions='actions' icons small)
</template>
