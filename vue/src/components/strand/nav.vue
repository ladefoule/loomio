<script lang="coffee">
import EventBus from '@/shared/services/event_bus'
import Records from '@/shared/services/records'
import marked from 'marked'
import {customRenderer, options} from '@/shared/helpers/marked.coffee'
marked.setOptions Object.assign({renderer: customRenderer()}, options)
import { debounce, truncate, first, last, some, drop, min, compact, without, sortedUniq } from 'lodash'

export default

  props:
    discussion: Object
    loader: Object

  data: ->
    topDate: null
    bottomDate: null
    open: null
    knobOffset: 0
    knobHeight: 32
    trackHeight: 400
    position: 0
    minUnitHeight: 16
    presets: []
    knobVisible: false
    keys: []
    visibleKeys: []
    headings: []
    context: ''

  mounted: ->
    EventBus.$on 'toggleThreadNav', => @open = !@open
    EventBus.$on 'scrollThreadNav', =>
      return if @knobVisible or !document.querySelector('.thread-sidebar .v-navigation-drawer__content')
      @$vuetify.goTo('.thread-nav__knob', { container: '.thread-sidebar .v-navigation-drawer__content', offset: 100 })


    Records.events.fetch
      params:
        exclude_types: 'group discussion'
        discussion_id: @discussion.id
        pinned: true
        per: 200

    Records.events.remote.fetch
      path: 'position_keys'
      params:
        discussion_id: @discussion.id
        per: 1000
    .then (data) =>
      @keys = [@discussion.createdEvent().positionKey].concat data.position_keys
      @topDate = @discussion.createdAt
      @bottomDate = @discussion.lastActivityAt
      @bottomPosition = @keys.length

    @watchRecords
      key: 'thread-nav'+@discussion.id
      collections: ["events", "discussions"]
      query: =>
        return unless @discussion && !@discussion.discardedAt && @discussion.createdEvent()
        parser = new DOMParser()

        if @discussion.descriptionFormat == 'md'
          @context = marked(@discussion.description)
        else
          @context = @discussion.description

        doc = parser.parseFromString(@context, 'text/html')
        @headings = Array.from(doc.querySelectorAll('h1,h2,h3')).map (el) =>
          {id: el.id, name: el.textContent}

        @presets = Records.events.collection.chain()
          .find({pinned: true, discussionId: @discussion.id})
          .simplesort('position').data()
        @setHeight()

    EventBus.$on 'visibleKeys', (keys) =>
      @visibleKeys = keys
      firstPosition = @keys.indexOf(first(keys))
      lastPosition = @keys.indexOf(last(keys))
      @knobOffset = @offsetFor(firstPosition)
      @knobHeight = @unitHeight * (lastPosition - firstPosition + 1)

  methods:
    setKnobVisible: (visible) ->
      @knobVisible = visible

    setHeight: ->
      @trackHeight = 400
      while ((@minOffset() || @minUnitHeight) < @minUnitHeight) && (@trackHeight < 500)
        @trackHeight = @trackHeight * 1.1

    minOffset: ->
      distances = [2..@presets.length].map (i) =>
        if @presets[i] && @presets[i-1]
          parseInt (@presets[i].position * @unitHeight) - (@presets[i-1].position * @unitHeight)
      min compact distances

    onTrackClicked: (event) ->
      @moveKnob(event)
      @goToPosition(@position)

    moveKnob: (event) ->
      event.preventDefault()
      event.stopImmediatePropagation()
      adjust = if @knobHeight < 64
           32
        else
          parseInt(@knobHeight / 2)

      @knobOffset = @getEventOffset(event)
      @position = @positionFor(@getEventOffset(event))

    getEventOffset: (event) ->
      # touch event structure differs from that of mouse event
      clientY = if event.touches
        event.touches[0].clientY
      else
        event.clientY

      offset = clientY - @$refs.slider.getBoundingClientRect().top
      if offset < 0
        0
      else if offset > @trackHeight
        @trackHeight
      else
        offset

    onMouseDown: ->
      onMouseMove = @moveKnob

      onMouseUp = =>
        document.removeEventListener 'mousemove', onMouseMove
        document.removeEventListener 'mouseup', onMouseUp
        @goToPosition(@position)

      document.addEventListener 'mousemove', onMouseMove
      document.addEventListener 'mouseup', onMouseUp

    onTouchStart: ->
      onTouchMove = @moveKnob

      onTouchEnd = =>
        document.removeEventListener 'touchmove', onTouchMove
        document.removeEventListener 'touchend', onTouchEnd
        @goToPosition(@position)

      document.addEventListener 'touchmove', onTouchMove, { passive: false }
      document.addEventListener 'touchend', onTouchEnd

    goToPosition: (position) ->
      unless (@$route.query && @$route.query.k == position)
        @$router.replace(query: {k: @keys[position]}, params: {sequence_id: null, comment_id: null}).catch (err) => {}

    offsetFor: (position) ->
      position * @unitHeight

    positionFor: (offset) ->
      position = parseInt(offset / @unitHeight)  - 1
      # console.log 'offset', offset, 'position', position, @keys[position]
      ((position < 0) && 0) || position

    goToContextHeading: (id) ->
      # load context with the id

  watch:
    'discussion.newestFirst':
      immediate: true
      handler: ->
        return unless @discussion

  computed:
    firstKey: -> first(@keys)
    lastKey: -> last(@keys)
    displayKey: ->
      # if under halfway, use first visible position, otherwise use loas visible position
      @visibleKeys[parseInt((@visibleKeys.length - 1)/2)]
    displayPosition: ->
      return 1 if @keys.indexOf(@visibleKeys[0]) == 0
      return (@keys.length - 1) if @keys.indexOf(last(@visibleKeys)) == (@keys.length - 1)
      @keys.indexOf( @visibleKeys[parseInt((@visibleKeys.length - 1)/2)])
    unitHeight: ->
      @trackHeight / @keys.length

</script>

<template lang="pug">
v-navigation-drawer.lmo-no-print.disable-select.thread-sidebar(v-if="discussion && bottomDate && topDate" v-model="open" :permanent="$vuetify.breakpoint.mdAndUp" width="230px" app fixed right clipped color="background" floating)
  a.thread-nav__date(:to="urlFor(discussion)" @click="scrollTo('#context')" v-t="'activity_card.context'")
  a.d-block.text-caption(v-for="heading, index in headings" :key="index" :href="'#'+heading.id") {{heading.name}}
  router-link.thread-nav__date(:to="{query:{k: firstKey}, params: {p: null, sequence_id: null}}") {{approximateDate(topDate)}}
  .thread-nav(:style="{height: trackHeight+'px'}")
    .thread-nav__track(ref="slider" :style="{height: trackHeight+'px'}" @click="onTrackClicked")
      .thread-nav__track-line
    .thread-nav__presets
      router-link.thread-nav__preset(v-for="event in presets" :key="event.id" :to="urlFor(event)" :style="{top: offsetFor(keys.indexOf(event.positionKey))+'px'}")
        .thread-nav__preset--line
        .thread-nav__preset--title {{event.pinnedTitle || event.suggestedTitle()}}
        .thread-nav__stance-icon-container(v-if="event.model().isA('poll') && event.model().iCanVote()")
          poll-common-stance-icon.thread-nav__stance-icon(:poll="event.model()" :stance="event.model().myStance()" :size='18')
    .thread-nav__knob(:style="{top: knobOffset+'px', height: knobHeight+'px'}" ref="knob" @mousedown="onMouseDown" v-touch:start="onTouchStart" v-observe-visibility="{callback: setKnobVisible}")
      span(style="display: block; white-space: nowrap; overflow: visible;") {{displayPosition}} / {{keys.length - 1}}

  router-link.thread-nav__date(:to="{query:{k: lastKey}, params: {sequence_id: null}}") {{approximateDate(bottomDate)}}
  //- | {{keys.indexOf(visibleKeys[visibleKeys.length -1])}}
  //- | {{visibleKeys}}
</template>

<style lang="sass">
</style>
