<script lang="coffee">
import { capitalize } from 'lodash'
import Session from '@/shared/services/session'
import Records from '@/shared/services/records'

export default
  props:
    model: Object
    icon: Boolean
    small: Boolean

  data: ->
    search: null
    closeEmojiMenu: false

  methods:
    insert: (emoji) ->
      params =
        reactableType: capitalize(@model.constructor.singular)
        reactableId: @model.id
        userId: Session.user().id

      reaction = Records.reactions.find(params)[0] || Records.reactions.build(params)
      reaction.reaction = ":#{emoji}:"
      reaction.save()
      @closeEmojiMenu = true


</script>

<template lang="pug">
v-menu.reactions-input(:close-on-content-click="true" v-model="closeEmojiMenu")
  template(v-slot:activator="{on, attrs}")
    v-btn.emoji-picker__toggle.action-button(:icon="icon" :small="small" :text="!icon" v-on="on" v-bind="attrs" )
      span(v-if="!icon" v-t="'action_dock.react'")
      v-icon(v-else :small="small") mdi-emoticon-outline
  emoji-picker(:insert="insert" :is-poll="model.isA('poll') || model.isA('stance') || model.isA('outcome')")
</template>

<style lang="sass">
.reactions-input
	display: flex
	align-items: center

</style>
