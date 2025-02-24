<script lang="coffee">
import AbilityService from '@/shared/services/ability_service'

import { pick, assign, compact, min } from 'lodash'
import CommentService from '@/shared/services/comment_service'
import EventService from '@/shared/services/event_service'
import Session from '@/shared/services/session'

export default
  components:
    ThreadItem: -> import('@/components/thread/item.vue')

  props:
    event: Object
    isReturning: Boolean

  computed:
    replyMargin: ->
      min([@event.depth, @event.discussion().maxDepth - 1]) * 56

    commentActions: -> CommentService.actions(@eventable, @)
    eventActions: -> EventService.actions(@event, @)
    eventable: -> @event.model()
    dockActions: ->
      if AbilityService.canEditOwnComment(@eventable)
        edit_comment = 'edit_comment'
      else
        reply_to_comment = 'reply_to_comment'
        show_history = 'show_history'

      assign(
        pick @commentActions, compact ['react', reply_to_comment, 'translate_comment', edit_comment, show_history]
      ,
        pick @eventActions, ['pin_event', 'unpin_event']
      )

    menuActions: ->
      if AbilityService.canEditOwnComment(@eventable)
        show_history = 'show_history'
        reply_to_comment = 'reply_to_comment'

      assign(
        pick @commentActions, compact [reply_to_comment, show_history, 'admin_edit_comment', 'notification_history', 'discard_comment', 'undiscard_comment']
      ,
        pick @eventActions, ['move_event', 'copy_url']
      )

  data: ->
    confirmOpts: null
    showReplyForm: false
    newComment: null

</script>

<template lang="pug">
thread-item.new-comment(id="'comment-'+ eventable.id" :event="event" :is-returning="isReturning")
  template(v-slot:actions)
    action-dock(small :model='eventable' :actions='dockActions' :menu-actions='menuActions')
  formatted-text.thread-item__body.new-comment__body(:model="eventable" column="body")
  link-previews(:model="eventable")
  document-list(:model='eventable')
  attachment-list(:attachments="eventable.attachments")
  template(v-slot:append)
    div(:style="{'margin-left': replyMargin+'px'}")
      comment-form(v-if="showReplyForm" :comment="newComment" @comment-submitted="showReplyForm = false" @cancel-reply="showReplyForm = false" autofocus)
</template>
