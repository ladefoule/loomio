<script lang="coffee">
import EventBus from '@/shared/services/event_bus'

export default
  data: ->
    flash: {}
    isOpen: false
    timeout: 6000
    message: ''
    options: {}
  created: ->
    EventBus.$on 'flashMessage', (flash) =>
      @flash = flash
      @isOpen = true
</script>

<template lang="pug">
v-snackbar.flash-root(:color="flash.level == 'success' ? 'primary' : flash.level" v-model="isOpen" :timeout="timeout" top)
  span.flash-root__message(role="status" aria-live="assertive" v-t="{path: flash.message, args: flash.options}")
  .flash-root__action(v-if="flash.actionFn")
    a(@click="flash.actionFn()", v-t="flash.action")
</template>
