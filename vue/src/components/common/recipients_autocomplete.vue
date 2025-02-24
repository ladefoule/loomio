<script lang="coffee">
import EventBus from '@/shared/services/event_bus'
import Records from '@/shared/services/records'
import Session from '@/shared/services/session'
import AnnouncementService from '@/shared/services/announcement_service'
import {map, debounce, without, compact, filter, uniq, uniqBy, find, difference} from 'lodash'
import AbilityService from '@/shared/services/ability_service'
import NotificationsCount from './notifications_count'

export default
  components: {
    NotificationsCount
  }

  props:
    autofocus: Boolean
    label: String
    placeholder: String
    hint: String
    reset: Boolean
    model: Object
    existingOnly: Boolean
    includeActor: Boolean
    excludeMembers: Boolean
    excludedAudiences:
      type: Array
      default: -> []
    excludedUserIds:
      type: Array
      default: -> []
    initialRecipients:
      type: Array
      default: -> []

  data: ->
    query: ''
    suggestedUserIds: []
    suggestions: []
    recipients: []
    loading: false

  mounted: ->
    @recipients = @initialRecipients
    @fetchAndUpdateSuggestions()

  watch:
    'model.groupId': (groupId) ->
      @suggestedUserIds = []
      @newRecipients(@initialRecipients)
      @fetchAndUpdateSuggestions()

    reset: ->
      @query = ''
      @recipients = @initialRecipients
      @fetchAndUpdateSuggestions()

    recipients: (val) ->
      @newRecipients(val)
      @$emit('new-recipients', val)
      @updateSuggestions()

    query: (q) ->
      @$emit('new-query', q)
      @fetchAndUpdateSuggestions()

  methods:
    fetchSuggestions: debounce ->
      return unless @query
      existingOnly = (@existingOnly && {existing_only: 1}) || {}
      @loading = true
      Records.fetch
        path: 'announcements/search'
        params: {
          exclude_types: 'group inviter'
          q: @query
          per: 20
          include_actor: (@includeActor && 1) || null
          ...existingOnly
          ...@model.bestNamedId()
        }
      .then (data) =>
        @suggestedUserIds = uniq @suggestedUserIds.concat(data['users'].map (u) -> u.id)
        @updateSuggestions()
      .finally =>
        @loading = false
    , 500

    fetchAndUpdateSuggestions: ->
      @fetchSuggestions()
      @updateSuggestions()

    newRecipients: (val) ->
      @model.recipientAudience = (find(val, (o) -> o.type == 'audience') || {}).id
      @model.recipientUserIds = map filter(val, (o) -> o.type == 'user'), 'id'
      @model.recipientEmails = map filter(val, (o) -> o.type == 'email'), 'name'

    findUsers: ->
      return [] unless @query
      chain = Records.users.collection.chain()

      chain = chain.find(id: {$in: difference(@suggestedUserIds, @excludedUserIds)})
      chain = chain.find(emailVerified: true)

      chain = chain.find
        $or: [
          {name: {'$regex': ["^#{@query}", "i"]}}
          {username: {'$regex': ["^#{@query}", "i"]}}
          {name: {'$regex': [" #{@query}", "i"]}}
        ]

      chain.data()

    notificationsCount: ->
      sum(@recipients.map((r) => r.size || 1))

    expand: (item) ->
      excludeMembers = (@excludeMembers && {exclude_members: 1}) || {}
      return false if @model.anonymous
      Records.fetch
        path: 'announcements/audience'
        params: {
          recipient_audience: item.id
          include_actor: (@includeActor && 1) || null
          ...excludeMembers
          ...@model.bestNamedId()
        }
      .then (data) =>
        @remove(item)
        userIds = (data['users'] || []).map((u) -> u.id)
        @suggestedUserIds = uniq @suggestedUserIds.concat(userIds)
        Records.users.find(userIds).forEach (u) =>
          @recipients.push
            id: u.id
            type: 'user'
            name: u.nameOrEmail()
            user: u

    remove: (item) ->
      @recipients = filter @recipients, (r) ->
        !(r.id == item.id && r.type == item.type)

    emailToRecipient: (email) ->
      id: email
      type: 'email'
      icon: 'mdi-email-outline'
      name: email

    updateSuggestions: ->
      if @query && @canAddGuests
        emails = uniq(@query.match(/[^\s:,;'"`<>]+?@[^\s:,;'"`<>]+\.[^\s:,;'"`<>]+/g) || [])

        # catch paste of multiple email addresses, or failure to press enter after an email address
        if emails.length > 1 or (emails.length == 1 && [',', ' '].includes(@query.slice(-1)))
          objs = uniqBy @recipients.concat(emails.map(@emailToRecipient)), 'id'
          @recipients = objs
          @suggestions = objs
          @query = ''
          return
        else if emails.length == 1
          @suggestions = @recipients.concat emails.map(@emailToRecipient)
          return

      members = @findUsers().map (u) ->
        id: u.id
        type: 'user'
        name: u.nameOrEmail()
        user: u

      audiences = @audiences.map (a) ->
        id: a.id
        type: 'audience'
        icon: 'mdi-account-group'
        name: a.name
        size: a.size

      @suggestions = @recipients.concat(audiences).concat(members)

  computed:
    canAddGuests: -> AbilityService.canAddGuests(@model)
    canNotifyGroup: -> AbilityService.canAnnounce(@model)
    modelName: -> @model.constructor.singular

    audiences: ->
      ret = []
      if @recipients.length == 0
        AnnouncementService.audiencesFor(@model).forEach (audience) =>
          switch audience
            when 'group'
              ret.push
                id: 'group'
                name: @$t('announcement.audiences.group', name: @model.group().name)
                size: @model.group().acceptedMembershipsCount
                icon: 'mdi-account-group'
            when 'discussion_group'
              ret.push
                id: 'discussion_group'
                name: @$t('announcement.audiences.discussion_group')
                size: @model.discussion().membersCount
                icon: 'mdi-forum'
            when 'voters'
              ret.push
                id: 'voters'
                name: @$t('announcement.audiences.voters', pollType: @model.poll().translatedPollType())
                size: @model.poll().votersCount
                icon: 'mdi-forum'
            when 'decided_voters'
              ret.push
                id: 'decided_voters'
                name: @$t('announcement.audiences.decided_voters')
                size: @model.poll().decidedVotersCount
                icon: 'mdi-forum'
            when 'undecided_voters'
              ret.push
                id: 'undecided_voters'
                name: @$t('announcement.audiences.undecided_voters')
                size: @model.poll().undecidedVotersCount
                icon: 'mdi-forum'

        unless @excludedAudiences.includes('group')
          groups = switch @model.constructor.singular
            when 'poll', 'discussion', 'outcome'
              compact [
                @model.group(),
                (@model.group().parentId && @model.group().parent()),
              ].concat(
                without(@model.group().parentOrSelf().subgroups(), @model.group())
              )
            else
              []

          groups.filter(AbilityService.canNotifyGroup).forEach (group) =>
            if group.acceptedMembershipsCount
              ret.push
                id: "group-#{group.id}"
                name: @$t('announcement.audiences.group', name: group.name)
                size: group.acceptedMembershipsCount
                icon: 'mdi-forum'

      ret.filter (a) =>
        !@excludedAudiences.includes(a.id) &&
        ((@query && a.name.match(new RegExp(@query, 'i'))) || true)

</script>

<template lang="pug">
div.recipients-autocomplete
  //- chips attribute is messing with e2es; no behaviour change noticed
  v-autocomplete.announcement-form__input(
    multiple
    return-object
    auto-select-first
    hide-selected
    v-model='recipients'
    @change="query = null"
    :search-input.sync="query"
    item-text='name'
    :hide-no-data='(recipients.length > 0) || loading'
    :loading="loading"
    :label="label"
    :placeholder="placeholder"
    :items='suggestions'
    )
    template(v-slot:no-data)
      v-list-item
        v-list-item-icon
          v-icon(v-if="!query") mdi-account-search
          v-icon(v-if="query") mdi-information-outline
        v-list-item-content
          v-list-item-title
            span(v-if="query" v-t="'common.no_results_found'")
            span(v-else)
              span(v-if="canAddGuests" v-t="'announcement.search_by_name_or_email'")
              span(v-if="!canAddGuests" v-t="'announcement.search_by_name'")
          v-list-item-subtitle
            span(v-if="!canAddGuests && !canNotifyGroup"
                 v-t="'announcement.only_admins_can_announce_or_invite'")
            span(v-if="!canAddGuests && canNotifyGroup"
                 v-t="'announcement.only_admins_can_invite'")
            span(v-if="canAddGuests && !canNotifyGroup"
                 v-t="'announcement.only_admins_can_announce'")
    template(v-slot:selection='data')
      v-chip.chip--select-multi(
        v-if="data.item.type =='audience'"
        :value='data.selected'
        close
        color='primary'
        @click:close='remove(data.item)'
        @click='expand(data.item)')
        span
          v-icon.mr-1(small) {{data.item.icon}}
        span {{ data.item.name }}
      v-chip.chip--select-multi(
        v-else
        :value='data.selected'
        close
        outlined
        color='primary'
        @click:close='remove(data.item)')
        span
          user-avatar.mr-1(v-if="data.item.type == 'user'"
                           :user="data.item.user" size="small" no-link)
          v-icon.mr-1(v-else small) {{data.item.icon}}
        span {{ data.item.name }}
        span(v-if="data.item.type == 'user' && currentUserId == data.item.id")
          space
          span ({{ $t('common.you') }})
    template(v-slot:item='data')
      v-list-item-avatar
        user-avatar(v-if="data.item.type == 'user'" :user="data.item.user" :size="24" no-link)
        v-icon.mr-1(v-else small) {{data.item.icon}}
      v-list-item-content.announcement-chip__content
        v-list-item-title
          span {{data.item.name}}
          span(v-if="data.item.type == 'user' && currentUserId == data.item.id")
            space
            span ({{ $t('common.you') }})
  notifications-count(v-show="recipients.length" :model='model' :exclude-members="excludeMembers" :include-actor="includeActor")
</template>
