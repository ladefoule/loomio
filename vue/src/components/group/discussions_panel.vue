<script lang="coffee">
import Records            from '@/shared/services/records'
import AbilityService     from '@/shared/services/ability_service'
import EventBus           from '@/shared/services/event_bus'
import RecordLoader       from '@/shared/services/record_loader'
import PageLoader         from '@/shared/services/page_loader'
import { map, debounce, orderBy, intersection, compact, omit, filter, concat, uniq} from 'lodash'
import Session from '@/shared/services/session'

export default
  created: ->
    @onQueryInput = debounce (val) =>
      @$router.replace(@mergeQuery(q: val))
    , 1000
    @init()
    EventBus.$on 'signedIn', @init

  beforeDestroy: ->
    EventBus.$off 'signedIn', @init

  data: ->
    group: null
    discussions: []
    searchResults: []
    loader: null
    searchLoader: null
    groupIds: []
    per: 25

  methods:
    routeQuery: (o) ->
      @$router.replace(@mergeQuery(o))

    openStartDiscussionModal: ->
      EventBus.$emit 'openModal',
        component: 'DiscussionForm'
        props:
          discussion: Records.discussions.build
            descriptionFormat: Session.defaultFormat()
            groupId: @group.id

    beforeDestroy: ->
      EventBus.$off 'joinedGroup'

    init: ->
      Records.groups.findOrFetch(@$route.params.key).then (group) =>
        @group = group

        EventBus.$emit 'currentComponent',
          page: 'groupPage'
          title: @group.name
          group: @group
          search:
            placeholder: @$t('navbar.search_threads', name: @group.parentOrSelf().name)

        EventBus.$on 'joinedGroup', (group) => @fetch()

        @refresh()

        @watchRecords
          key: @group.id
          collections: ['discussions', 'groups', 'memberships']
          query: => @query()

    refresh: ->
      @loader = new PageLoader
        path: 'discussions'
        order: 'lastActivityAt'
        params:
          group_id: @group.id
          exclude_types: 'group outcome'
          filter: @$route.query.t
          subgroups: @$route.query.subgroups || 'mine'
          tags: @$route.query.tag
          per: @per

      @searchLoader = new RecordLoader
        collection: 'searchResults'
        params:
          exclude_types: 'group stance outcome poll'
          subgroups: @$route.query.subgroups || 'all'
          group_id: @group.id

      @fetch()
      @query()

    query: ->
      return unless @group
      # console.log 'running query: page', @page, 'loader pageWindow[page]', @loader.pageWindow[@page]
      @publicGroupIds = @group.publicOrganisationIds()

      @groupIds = switch (@$route.query.subgroups || 'mine')
        when 'mine' then uniq(concat(intersection(@group.organisationIds(), Session.user().groupIds()), @publicGroupIds, @group.id)) # @group.id is present if @group is a subgroup of parentgroup that i'm a member of, and that parent group has parentMembersCanSeeDiscussions
        when 'all' then @group.organisationIds()
        else [@group.id]

      # console.log 'user group ids', Session.user().groupIds()
      # console.log 'org ids', @group.organisationIds()
      # console.log 'intersection ids', orderBy intersection(@group.organisationIds(), Session.user().groupIds())
      # console.log 'records found', Records.discussions.collection.chain().find(groupId: {'$in': @group.organisationIds()}).data().length

      if @$route.query.q
        chain = Records.searchResults.collection.chain()
        chain = chain.find(groupId: {$in: @group.parentOrSelf().organisationIds()})
        chain = chain.find(query: @$route.query.q)
        @searchResults = orderBy(chain.data(), 'rank', 'desc')
      else
        chain = Records.discussions.collection.chain()
        chain = chain.find(discardedAt: null)
        chain = chain.find(groupId: {$in: @groupIds})

        switch @$route.query.t
          when 'unread'
            chain = chain.where (discussion) -> discussion.isUnread()
          when 'closed'
            chain = chain.find(closedAt: {$ne: null})
          when 'all'
            true # noop
          else
            chain = chain.find(closedAt: null)

        if @$route.query.tag

          tag = Records.tags.find(groupId: @group.parentOrSelf().id, name: @$route.query.tag)[0]
          chain = chain.find({tagIds: {'$contains': tag.id}})

        if @loader.pageWindow[@page]
          if @page == 1
            chain = chain.find(lastActivityAt: {$gte: @loader.pageWindow[@page][0]})
          else
            chain = chain.find(lastActivityAt: {$jbetween: @loader.pageWindow[@page]})
          @discussions = chain.simplesort('lastActivityAt', true).data()
        else
          @discussions = []

    fetch: ->
      if @$route.query.q
        @searchLoader.fetchRecords(q: @$route.query.q, from: 0)
      else
        @loader.fetch(@page).then( => @query())

    filterName: (filter) ->
      switch filter
        when 'unread' then 'discussions_panel.unread'
        when 'all' then 'discussions_panel.all'
        when 'closed' then 'discussions_panel.closed'
        when 'subscribed' then 'change_volume_form.simple.loud'
        else
          'discussions_panel.open'

  watch:
    '$route.params': 'init'
    '$route.query': 'refresh'
    'page' : ->
      @fetch()
      @query()

  computed:
    page:
      get: -> parseInt(@$route.query.page) || 1
      set: (val) ->
        @$router.replace
          query:
            page: val

    totalPages: ->
      Math.ceil(parseFloat(@loader.total) / parseFloat(@per))

    pinnedDiscussions: ->
      orderBy(@discussions.filter((discussion) -> discussion.pinned), ['title'], ['asc'])

    regularDiscussions: ->
      orderBy(@discussions.filter((discussion) -> !discussion.pinned), ['lastActivityAt'], ['desc'])

    groupTags: ->
      @group && @group.parentOrSelf().tags().filter (tag) -> tag.taggingsCount > 0

    loading: ->
      @loader.loading || @searchLoader.loading

    noThreads: ->
      !@loading && @discussions.length == 0

    canViewPrivateContent: ->
      AbilityService.canViewPrivateContent(@group)

    canStartThread: ->
      AbilityService.canStartThread(@group)

    isLoggedIn: ->
      Session.isSignedIn()

    unreadCount: ->
      filter(@discussions, (discussion) -> discussion.isUnread()).length

    suggestClosedThreads: ->
      ['undefined', 'open', 'unread'].includes(String(@$route.query.t)) && @group && @group.closedDiscussionsCount

</script>

<template lang="pug">
div.discussions-panel(v-if="group")
  v-layout.py-3(align-center wrap)
    v-menu
      template(v-slot:activator="{ on, attrs }")
        v-btn.mr-2.text-lowercase.discussions-panel__filters(v-on="on" v-bind="attrs" text)
          span(v-t="{path: filterName($route.query.t), args: {count: unreadCount}}")
          v-icon mdi-menu-down
      v-list(dense)
        v-list-item.discussions-panel__filters-open(@click="routeQuery({t: null})")
          v-list-item-title(v-t="'discussions_panel.open'")
        v-list-item.discussions-panel__filters-all(@click="routeQuery({t: 'all'})")
          v-list-item-title(v-t="'discussions_panel.all'")
        v-list-item.discussions-panel__filters-closed(@click="routeQuery({t: 'closed'})")
          v-list-item-title(v-t="'discussions_panel.closed'")
        v-list-item.discussions-panel__filters-unread(@click="routeQuery({t: 'unread'})")
          v-list-item-title(v-t="{path: 'discussions_panel.unread', args: { count: unreadCount }}")

    v-menu(offset-y)
      template(v-slot:activator="{ on, attrs }")
        v-btn.mr-2.text-lowercase(v-on="on" v-bind="attrs" text)
          span(v-if="$route.query.tag") {{$route.query.tag}}
          span(v-else v-t="'loomio_tags.tags'")
          v-icon mdi-menu-down
      v-sheet.pa-1
        tags-display(:tags="group.parentOrSelf().tags()" show-counts)
    v-text-field.mr-2.flex-grow-1(clearable solo hide-details :value="$route.query.q" @input="onQueryInput" :placeholder="$t('navbar.search_threads', {name: group.name})" append-icon="mdi-magnify" :loading="searchLoader.loading")
    v-btn.discussions-panel__new-thread-button(:to="'/d/new?group_id='+group.id" color='primary' v-if='canStartThread' v-t="'navbar.start_thread'")

  v-card.discussions-panel(outlined)
    div(v-if="loader.status == 403")
      p.pa-4.text-center(v-t="'error_page.forbidden'")
    div(v-else)
      .discussions-panel__content(v-if="!$route.query.q")
        .discussions-panel__list--empty.pa-4(v-if='noThreads' :value="true")
          p.text-center(v-if='canViewPrivateContent' v-t="'group_page.no_threads_here'")
          p.text-center(v-if='!canViewPrivateContent' v-t="'group_page.private_threads'")
        .discussions-panel__list.thread-preview-collection__container(v-if="discussions.length")
          v-list.thread-previews(two-line)
            thread-preview(:show-group-name="groupIds.length > 1" v-for="thread in pinnedDiscussions" :key="thread.id" :thread="thread" group-page)
            thread-preview(:show-group-name="groupIds.length > 1" v-for="thread in regularDiscussions" :key="thread.id" :thread="thread" group-page)

        loading(v-if="loading && discussions.length == 0")

        v-pagination(v-model="page" :length="totalPages" :total-visible="7" :disabled="totalPages == 1")
        .d-flex.justify-center
          router-link.discussions-panel__view-closed-threads.text-center.pa-1(:to="'?t=closed'" v-if="suggestClosedThreads" v-t="'group_page.view_closed_threads'")

      .discussions-panel__content.pa-4(v-if="$route.query.q")
        p.text-center.discussions-panel__list--empty(v-if='!searchResults.length && !searchLoader.loading' v-t="{path: 'discussions_panel.no_results_found', args: {search: $route.query.q}}")
        thread-search-result(v-else v-for="result in searchResults" :key="result.id" :result="result")
</template>

<style lang="sass">
.overflow-x-auto
  overflow-x: auto
</style>
