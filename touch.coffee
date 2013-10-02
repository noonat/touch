isTouch = window.ontouchstart != undefined

sign = (x) ->
  if x < 0 then -1 else if x > 0 then 1 else 0

class Touchable
  constructor: (element, opts) ->
    opts ||= {}
    @element = if element.length then element[0] else element
    @events =
      start: if isTouch then 'touchstart' else 'mousedown'
      move: if isTouch then 'touchmove' else 'mousemove'
      end: if isTouch then 'touchend' else 'mouseup'
    @onEventBinding = => @onEvent.apply this, arguments
    @addEvent @events.start
    @addEvent 'click' if !opts.clickable

  destroy: ->
    @removeEvent @events.start
    @removeEvent @events.move
    @removeEvent @events.end
    @removeEvent 'click'

  addEvent: (event) ->
    @element.addEventListener event, @onEventBinding, false

  removeEvent: (event) ->
    @element.removeEventListener event, @onEventBinding

  ignoreEvent: (event) ->
    switch event.type
      when @events.start
        return true if event.touches?.length > 1
        focused = document.querySelectorAll(':focus')[0]
        return true if event.target == focused && @isInput focused
      when @events.move
        return true if event.touches?.length > 1
    false

  onEvent: (event) ->
    return if @ignoreEvent event
    name = switch event.type
      when @events.start then 'start'
      when @events.move then 'move'
      when @events.end then 'end'
      when 'click' then 'click'
    this[name]?(event)

  click: (event) ->
    event.preventDefault()

  start: (event) ->
    event.preventDefault()
    @touch = new Touch event
    @addEvent @events.move
    @addEvent @events.end
    @dispatchEvent 'swipestart', event

  move: (event) ->
    @touch.move event
    @dispatchEvent 'swipemove', event if @touch.moved

  end: (event) ->
    @removeEvent @events.move, @events.end
    @touch.end event
    if @touch.moved
      document.querySelectorAll(':focus')[0]?.blur?()
    else if @isInput event.target
      event.target.focus()
    else
      @dispatchEvent 'tap', event
    @dispatchEvent 'swipeend', event

  dispatchEvent: (type, originalEvent) ->
    event = document.createEvent 'Event'
    event.initEvent type, true, true
    event.detail = @touch
    @touch.pointForEvent(originalEvent).target.dispatchEvent event

  isInput: (target) ->
    name = (target.nodeName || '').toLowerCase()
    type = (target.type || '').toLowerCase()
    switch name
      when 'select', 'textarea'
        true
      when 'input'
        type != 'button'
      else
        false

class Touch
  # Tracks details through the duration of a touch.

  constructor: (event) ->
    @start event

  start: (event) ->
    point = if isTouch then event.touches[0] else event
    @startTime = new Date().getTime()
    @startX = @currentX = +point.pageX
    @startY = @currentY = +point.pageY
    @startDeltaX = @deltaX = @currentDeltaX = 0
    @startDeltaY = @deltaY = @currentDeltaY = 0
    @signX = @currentSignX = 0
    @signY = @currentSignY = 0
    @moved = false

  move: (event) ->
    @updateFromEvent event
    if @startDeltaX < 10 && @startDeltaY < 10
      event.stopPropagation()
      @startDeltaX += Math.abs @currentDeltaX
      @startDeltaY += Math.abs @currentDeltaY
    else if @startDeltaX >= @startDeltaY
      event.stopPropagation()
      @moved = true

  end: (event) ->
    @updateFromEvent event
    @endTime = new Date().getTime()
    @deltaTime = @endTime - @startTime

  pointForEvent: (event) ->
    if isTouch
      if event.type == 'touchend'
        event.changedTouches[0]
      else
        event.touches[0]
    else
      event

  updateFromEvent: (event) ->
    point = @pointForEvent event
    @currentDeltaX = +point.pageX - @currentX
    @currentDeltaY = +point.pageY - @currentY
    @currentX = +point.pageX
    @currentY = +point.pageY
    @currentSignX = sign @currentDeltaX
    @currentSignY = sign @currentDeltaY
    @deltaX = @currentX - @startX
    @deltaY = @currentY - @startY
    @signX = sign @deltaX
    @signY = sign @deltaY
