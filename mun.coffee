# --
# Copyright © 2013 Frank Luan (@franklsf95)
# https://franklsf.org
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# “Software”), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ++

DEBUG     = 0
PRODUCT   = 1
THRESHOLD = DEBUG

jQuery ->
  log = (s, lv) -> console.log s #if lv >= THRESHOLD

  warn = (s, type) ->
    con = "<div class=\"alert"
    con += " alert-" + type  if type
    con += "\">" + "<button class=\"close\" data-dismiss=\"alert\">&times;</button>"
    con += "<strong>Warning! </strong>"  unless type
    con += s + "</div>"
    $(con).prependTo($ "#main-container").hide().slideDown()
    window.setTimeout ( -> $(".alert").alert('close') ), Master.get('variables').autoFadeTime

  notice = (s, type) ->
    con = "<div class=\"alert"
    con += " alert-" + type  if type
    con += "\">" + "<button class=\"close\" data-dismiss=\"alert\">&times;</button>"
    con += "<b>Warning: </b>"  unless type
    con += s + "</div>"
    $(con).prependTo($ "#main-wrapper").hide().fadeIn()
    window.setTimeout ( -> $(".alert").alert('close') ), Master.get('variables').autoFadeTime

  error   = (s) -> notice '<b>Error: </b>'   + s, 'error'
  success = (s) -> notice '<b>Success: </b>' + s, 'success'
  info    = (s) -> notice '<b>Notice: </b>'  + s, 'info'

  now = ->
    t = new Date
    t.getHours() + ":" + t.getMinutes()

  newModal = ->
    $theModal = $($("#tpl-init-sl").html().replace("\n", ""))
    $theModal.appendTo($("body")).attr("id", "modal-ha").modal "show"

  class SpeakersList extends Backbone.Model
    defaults: ->  # fix bug that list[] is declared static in prototype
      list: []
      current: -1
      time: 120
    initialize: (arr) ->
      log '@ Object SpeakersList created.', DEBUG
      @set 'list', arr  if arr?
    push: (s) ->
      if s?
        @get('list').push s
        @trigger 'change:list'
      @
    next: ->
      if @get 'current' == @get('list').length - 1
        return null
      @set 'current', @get('current') + 1
      (@get 'list')[@get 'current']

  class BaseSLView extends Backbone.View
    el: $ "#main-activity"
    events:
      "keypress": 'enterKey'
      "click #btn-gsl-next": 'nextCountry'
    initialize: (n, c) ->
      @name = n
      @cls  = c
      @listenTo @model, "change:list", @renderList
      @listenTo @model, "change:time", @renderTimer
      Master.register @, @name, @cls
      log '$ BaseSLView initialized.', DEBUG
    render: ->
      @$el.html ''
      @renderCurrent()
      @renderList()
      @renderTimer()
      $("#sl-add-country").tooltip(trigger: 'focus').focus()
      @
    renderCurrent: ->
      country = @model.get('list')[@model.get 'current']
      country ?= '(no speaker)'
      h = "<div class=\"highlight-country\">#{country}</div>"
      h += '<hr>'
      h += '<input type="text" id="sl-add-country" data-placement="bottom" data-original-title="Enter to Add Country">'
      h += '<button id="btn-gsl-next" class="btn btn-primary">Next Speaker</button>'
      @$el.append h
      @
    renderList: ->
      $(".pending-country-list").remove()
      list = @model.get 'list'
      h = '<ul class="pending-country-list">'
      h += "<li>#{c}</li>"  for c in list[@model.get('current') + 1 ..]
      h += "</ul>"
      @$el.append h
      @
    renderTimer: ->
      timerView.setTime @model.get 'time'
    enterKey: (e) ->
      if e.keyCode == 13
        c = $("#sl-add-country").val()
        @model.push(c)
        $("#sl-add-country").val('').focus()
    nextCountry: ->
      c = @model.next()
      if c?
        $(".highlight-country").html c
        @renderList()
        timerView.reset()
      else
        @terminate()
      return
    terminate: ->
      Master.unregister @cls
      @undelegateEvents()
      info @name + " exhausted."
      log @name + ' terminated.', DEBUG

  class GSLView extends BaseSLView
    initialize: ->
      super("General Speaker's List", 'gsl-view')
      log '\t$ GSLView initialized.', DEBUG

  class MCView extends BaseSLView
    initialize: (ops)->
      @params = ops # topic, time_tot, time_each
      super("Moderacted Caucus", 'mc-view')
      log '\t$ MCView initialized.', DEBUG
    render: ->
      @$el.html "<div class=\"mc-title\">Topic: #{@params.topic}</div><hr>"
      @renderCurrent()
      @renderList()
      @renderTimer()
      @$el.append '<hr><button class="btn btn-info" id="btn-exit-umc">Close this Moderated Caucus</button>'
      $("#sl-add-country").tooltip(trigger: 'focus').focus()
      @

  class UMCView extends Backbone.View
    el: $ "#main-activity"
    events: 
      "click #btn-exit-umc": "terminate"
    initialize: (ops) ->
      Master.register @, "Un-moderated Caucus", 'umc-view'
      timerView.setTime ops.time
      @render()
      log '\t$ UMCView initialized.', DEBUG
    render: ->
      h =  '<div class="mc-title">Un-moderated Caucus</div>'
      h += '<button class="btn btn-info" id="btn-exit-umc">Close this Un-moderated Caucus</button>'
      @$el.html h
    terminate: ->
      Master.unregister 'umc-view'
      @undelegateEvents()
      info "This Un-moderated Caucus has expired."

  class RollCallView extends Backbone.View
    el: $ "#main-activity"
    events:
      "click #btn-roll-call-present": "countryPresent"
      "click #btn-roll-call-absent":  "countryAbsent"
    className: 'roll-call-view'
    initialize: ->
      @current = 0
      @countryList = Master.get 'countryList'
      Master.register @, 'Roll Call', @className
      Master.set 'presentList', []
      appView.disable 'btn-roll-call'
      log '$ RollCallView initialized.', DEBUG
    render: ->
      if @current == @countryList.length
        @terminate()
      else
        h =  '<div class="highlight-country">' + this.countryList[this.current] + '</div>'
        h += '<button class="btn btn-success" id="btn-roll-call-present">Present (P)</button>'
        h += '<button class="btn btn-warning" id="btn-roll-call-absent">Absent (A)</button>'
        h += '<ul class="pending-country-list">'
        h += "<li>#{c}</li>" for c in @countryList[@current + 1 .. @current + 5]
        h += '<li>...</li>'  if @current + 5 < @countryList.length
        h += '</li>'
      @$el.html h
      @
    countryPresent: ->
      log @countryList[@current] + ' is present.', PRODUCT
      Master.addPresentCountry @countryList[@current]
      @current++
      @render()
    countryAbsent: ->
      log @countryList[@current] + ' is absent.', PRODUCT
      @current++
      @render()
    terminate: ->
      appView.enable 'btn-roll-call'
      appView.enable 'btn-gsl'
      appView.enable 'btn-motion'
      Master.unregister @className
      @undelegateEvents()
      success 'Roll Call completed.'
      log 'RollCallView terminated', DEBUG

  class SettingsModalView extends Backbone.View
    el: $ "#modal-settings"
    events:
      "click #submit-global-settings": "saveGlobalSettings"
    initialize: ->
      @listenTo Master, 'change:variables', @render
      log '$ SettingsModalView initialized.', DEBUG
    render: ->
      vars = Master.get 'variables'
      $("#input-" + i).val vars[i]   for i of vars
      log '> SettingsModalView refreshed.'
      @
    saveGlobalSettings: ->
      vars = {}
      for key of Master.get 'variables'
        vars[key] = $("#input-" + key).val()
      Master.set 'variables', vars

  class InitModalView extends Backbone.View
    el: $ "#modal-init"
    events:
      "click #submit-init": "initSession"
    initialize: ->
      log '$ InitModalView initialized.', DEBUG
    initSession: ->
      clist = $("#init-country-list").val().split '\n'
      clist = _(clist).filter( (v) -> v != '' )
      Master.set
        'sessionInfo':
          'committee': $("#init-committee").val()
          'abbr': $("#init-abbr").val()
          'topic': $("#init-topic").val()
          'sessionid': $("#init-sessionid").val()
        'countryList':
          clist
      appView.enable 'btn-roll-call'
      log 'Session successfully initialized!', PRODUCT
      @$el.modal 'hide'

  class TimerView extends Backbone.View
    $t:  $ "#global-timer"
    $tt: $ "#global-timer-total"
    el:  $ "#timer-wrapper"
    running: false
    events:
      "click #btn-timer-toggle": 'toggle'
      "click #btn-timer-reset": 'reset'
    initialize: ->
      @$t.timer()
      @$tt.timer()
      @setStart()
      log '$ TimerView initialized.', DEBUG
    setStart: ->
      $("#btn-timer-toggle").html "Start"
    setTime: (t, tt) ->
      tt ?= t
      @$t.timer time:t
      @$tt.timer time:tt
    toggle: ->
      if @running
        log 'Stopping timer1'
        @$t.timer 'stop'
        log 'Stopping timer2'
        @$tt.timer 'stop'
        @running = false
        $("#btn-timer-toggle").html "Continue"
      else
        log 'timer started.'
        @$t.timer 'start'
        @$tt.timer 'start'
        @running = true
        $("#btn-timer-toggle").html "Pause"
    reset: ->
      @toggle()  if @running
      @$t.timer 'reset'
      @$tt.timer 'reset'
      @setStart()
      log 'Timer reset', DEBUG

  class ControlView extends Backbone.View
    el: $ "#control-wrapper"
    initialize: ->
      log '$ ControlView initialized.', DEBUG
    events:
      "click #btn-toggle-fullscreen": "toggleFullscreen"
      "click #btn-pause"            : "togglePause"
      "click #btn-roll-call"        : "initRollCall"
      "click #btn-gsl"              : "initGeneralSL"
      "click #btn-motion-gsl-time"  : "motionGSLTime"
      "click #btn-motion-mc"        : "motionMC"
      "click #btn-motion-umc"       : "motionUMC"
      "change #input-xml-log"       : "readXML"
    toggleFullscreen: ->
      if screenfull.enabled
        screenfull.toggle()
        $("#btn-toggle-fullscreen").html (if screenfull.isFullscreen then 'Exit Fullscreen' else 'Fullscreen Mode')
    togglePause: ->
      if Master.get 'paused'
        log 'Session resumed.', PRODUCT
        return false
      else
        log 'Session paused.', PRODUCT
        bootbox.dialog "<span class=\"suspend-title\">This session is temporarily suspended.</span><hr>",
          [
            'label'   : 'Resume Session'
            'class'   : ''
            'callback': ->
              @togglePause
          ]
    initRollCall: ->
      @rollCallView = new RollCallView()
    initGeneralSL: ->
      @gsl = new SpeakersList()
      @gslView = new GSLView(model: @gsl)
    motionMC: ->
      @motionVote 'Motion for Moderated Caucus', 'm1', ->
        bootbox.dialog $("#tpl-init-mc").html(),
          [
              'label'   : 'Cancel'
              'class'   : ''
              'callback': ->
                info "This moderated caucus is cancelled."
            ,
              'label'   : 'OK'
              'class'   : 'btn-primary'
              'callback': ->
                log $("#init-mc-topic").val()
                @mcView = new MCView(
                  model: new SpeakersList,
                  topic     : $("#init-mc-topic").val()
                  time_tot  : $("#init-mc-total-time").val()
                  time_each : $("#init-mc-each-time").val()
                )
          ]
    motionUMC: ->
      @motionVote 'Motion for Un-moderated Caucus', 'm1', ->
        bootbox.prompt "Enter UMC Time (seconds):", (t) ->
          @umcView = new UMCView(time: t)
    motionGSLTime: ->
      if not @gsl?
        error "General Speaker's List must first be initialized!"
        return
      _gsl = @gsl
      @motionVote "Motion to Change General Speaking Time", 'm1', ->
        bootbox.prompt "Enter new Speaking Time (seconds):", (t) ->
          _gsl.set 'time': t
          success "General Speech's Time is changed to #{t} seconds."

    motionVote: (title, pass, callback) ->
      if not Master.get('sessionStats').cnt?
        error "Session Statistics must first be initialized!"
        info "The #{title} fails."
        return false
      if pass == 'm2'
        pass = Master.get('sessionStats').m2.value
      else if pass == 'm1'
        pass = Master.get('sessionStats').m1.value
      #else case number
      else
        pass = Master.get('sessionStats').m1.value
      bootbox.dialog "<div class=\"motion-title\">#{title}</div>This motion needs <code class=\"huge-number\">#{pass}</code> votes in favor to pass.",
        [
            'label'   : 'Fail'
            'class'   : 'btn-warning'
            'callback': ->
              info "The #{title} fails."
          ,
            'label'   : 'Pass'
            'class'   : 'btn-success'
            'callback': ->
              success "The #{title} passes."
              callback()
        ]
    readXML: (e) ->
      file = e.target.files[0]
      reader = new FileReader()
      reader.onloadend = ( (file)->
        (e) ->
          $("#xml-content").html e.target.result
      )(file)
      reader.readAsText file, 'UTF-8'

  class StatsView extends Backbone.View
    el: $ "#dl-session-stats"
    initialize: ->
      @listenTo Master, 'change:sessionStats', @render
      log '$ StatsView initialized.', DEBUG
    render: ->
      @$el.html ''
      arr = Master.get 'sessionStats'
      for i of arr
        @$el.append "<dt>#{arr[i].key}</dt><dd>#{arr[i].value}</dd>"
      @

  class IdleView extends Backbone.View
    el: $ "#main-activity"
    initialize: ->
      @render()
    render: ->
      @$el.html '<p>There is currently no active activity.</p>'
      log 'IdleView rendered', DEBUG

  class Item extends Backbone.Model
    initialize: ->
      log '@ Item created.', DEBUG
  class ItemSL extends Item
  class Timeline extends Backbone.Collection
    model: Item
    initialize: ->
      log '% Timeline (Item collection) created.', DEBUG
  class TimelineView extends Backbone.View
    el: $ "#timeline-wrapper"

  class MasterControl extends Backbone.Model
    defaults:
      countryList: []
      presentList: []
      sessionStats: []
      sessionInfo: {}
      ongoing:
        view: new IdleView()
        name: 'idle'
        cls : 'idle'
      threadStack: []
      variables:
        globalPrompt: 'This is a development version of mun.js'
        autoFadeTime: 3000
        mcDefaultTimeTotal: 300 # not-used yet
        mcDefaultTimeEach: 60   # not-used yet
      paused: false
    initialize: ->
      @on 'change:presentList', @calculate
      log '@ Object MasterControl created.', DEBUG
    register: (v, n, c) ->
      old = @get('ongoing')
      @get('threadStack').push old
      appView.unrender old
      old.view.undelegateEvents()

      @set 'ongoing',
        view: v
        name: n
        cls : c
      @logStack false, c
      v.render()
      @
    unregister: (c) ->
      return @  if @get('ongoing').cls != c or c == 'idle'
      appView.unrender(c)
      # get the last view back
      last = @get('threadStack').pop()
      @set 'ongoing',
        view: last.view
        name: last.name
        cls: last.cls
      last.view.render()
      last.view.delegateEvents()
      @logStack true, c
      @
    calculate: ->
      p = @get('presentList').length
      @set 'sessionStats',
        cnt:
          key: 'Country Present'
          value: p
        m1:
          key: 'Simple Majority'
          value: Math.floor(p / 2) + 1
        m2:
          key: 'Absolute Majority'
          value: Math.floor(p * 2 / 3) + 1
        spm:
          key: 'Sponsors Minimum'
          value: Math.round(p / 5)
    addPresentCountry: (c) ->
      @get('presentList').push c
      @trigger 'change:presentList'
    logStack: (isUnreg, cls) ->
      log ">>\tThread #{cls} " + (if isUnreg then 'popped out' else 'pushed in')
      log ">>\tThread Stack:"
      log "\t\t#{o.name}\t#{o.cls}", DEBUG  for o in @get('threadStack')
      return

  class AppView extends Backbone.View
    initialize: ->
      @listenTo Master, 'change:ongoing', @render
      @listenTo Master, 'change:variables', @renderVars
      @listenTo Master, 'change:sessionInfo', @renderTitle
      @render()
      log '$ AppView initialized.', DEBUG
      # start self-inspection
      if not (window.File && window.FileReader && window.FileList && window.Blob)
        warn 'XML File Processing Function not available.'
    render: (name, cls) ->
      $("#main-activity-name").html Master.get('ongoing').name
      $("#main-wrapper").addClass Master.get('ongoing').cls
    unrender: (cls) ->
      $("#main-wrapper").removeClass cls
      $("#main-activity").html ''
    renderTitle: ->
      $("#title-committee").html  Master.get('sessionInfo')['committee']
      $("#title-abbr").html       Master.get('sessionInfo')['abbr']
      $("#title-sessionid").html  Master.get('sessionInfo')['sessionid']
    renderVars: ->
      vars = Master.get('variables')
      $("#global-prompt").html vars.globalPrompt
      log "> Global variables applied."

    enable: (id) ->
      $('#' + id).removeAttr 'disabled'
      log id + ' enabled', DEBUG
    disable: (id) ->
      $('#' + id).attr('disabled', true)
      log id + ' disabled', DEBUG


  Master = new MasterControl()

  appView = new AppView()
  timerView = new TimerView()
  statsView = new StatsView()
  controlView = new ControlView()

  initModal = new InitModalView()
  settModal = new SettingsModalView()

  Master.trigger('change:variables')
  initModal.initSession()
  controlView.initRollCall()

  return