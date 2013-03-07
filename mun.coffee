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

  warn = (s, type, to) ->
    to ?= "#main-container"
    con = "<div class=\"alert"
    con += " alert-" + type  if type
    con += "\">" + "<button class=\"close\" data-dismiss=\"alert\">&times;</button>"
    con += "<strong>#{$.t('prompt.warning')}</strong>"  unless type
    con += s + "</div>"
    $(con).prependTo($ to).hide().slideDown()
    window.setTimeout ( -> $(".alert").alert('close') ), Master.get('variables').autoFadeTime

  notice = (s, type) -> warn s, type, "#main-wrapper"
  error   = (s) -> notice "<b>#{$.t('prompt.error')}</b>"   + s, 'error'
  success = (s) -> notice "<b>#{$.t('prompt.success')}</b>" + s, 'success'
  info    = (s) -> notice "<b>#{$.t('prompt.notice')}</b>"  + s, 'info'

  now = ->
    t = new Date
    min = t.getMinutes()
    min = '0' + min  if min < 10
    t.getHours() + ":" + min

  newModal = ->
    $theModal = $($("#tpl-init-sl").html().replace("\n", ""))
    $theModal.appendTo($("body")).attr("id", "modal-ha").modal "show"

  tlog = (s) -> timelineView.add $.t "log.#{s}"

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

  class BaseView extends Backbone.View
    initialize: (c) ->
      @name = $.t "views.#{c}"
      @cls  = c
      Master.register @, @name, @cls
      log "$ #{@name} initialized.", DEBUG
    terminate: ->
      Master.unregister @cls
      @undelegateEvents()
      log "$ #{@name} terminated.", DEBUG

  class BaseSLView extends BaseView
    el: $ "#main-activity"
    events: ->   # for children to extend
      "keypress": 'enterKey'
      "click #btn-gsl-next": 'nextCountry'
    initialize: (c) ->
      super c
      @listenTo @model, "change:list", @renderList
    render: ->
      @$el.html ''
      @renderCurrent()
      @renderList()
      @renderTimer()
      $("#sl-add-country").tooltip(trigger: 'focus').focus()
      @
    renderCurrent: ->
      country = @model.get('list')[@model.get 'current']
      country ?= $.t 'sl.ready'
      h = "<div class=\"highlight-country\">#{country}</div>"
      h += '<hr>'
      h += '<input type="text" id="sl-add-country" data-placement="bottom" data-original-title="' + $.t('sl.enterToAdd') + '">'
      h += '<button id="btn-gsl-next" class="btn btn-primary">' + $.t('sl.next') + '</button>'
      h += '<ul class="pending-country-list"></ul>'
      @$el.append h
      @
    renderList: ->
      list = @model.get 'list'
      h  = ''
      h += "<li>#{c}</li>"  for c in list[@model.get('current') + 1 ..]
      $(".pending-country-list").html h
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
      super()
      info @name + $.t 'prompt.exhausted'

  class GSLView extends BaseSLView
    initialize: ->
      super 'gsl-view'
      @listenTo @model, "change:time", @renderTimer
      log '\t$ GSLView initialized.', DEBUG

  class MCView extends BaseSLView
    events: ->
      _.extend {}, super, "click #btn-exit-mc": 'terminate'
    initialize: (ops)->
      @params = ops  # topic, time_tot, time_each
      super 'mc-view'
    render: ->
      @$el.html "<div class=\"mc-title\">#{$.t('mc.topic')}#{@params.topic}</div><hr>"
      @renderCurrent()
      @renderList()
      @renderTimer()
      @$el.append '<hr><button class="btn btn-info" id="btn-exit-mc">' + $.t('mc.close') + '</button>'
      $("#sl-add-country").tooltip(trigger: 'focus').focus()
      @
    renderTimer: ->
      timerView.setTime @params.time_each, @params.time_tot

  class UMCView extends BaseView
    el: $ "#main-activity"
    events:
      "click #btn-exit-umc": "terminate"
    initialize: (ops) ->
      super 'umc-view'
      timerView.setTime ops.time
      @render()
    render: ->
      h =  '<div class="mc-title">#{@name}</div>'
      h += '<button class="btn btn-info" id="btn-exit-umc">' + $.t('mc.close') + '</button>'
      @$el.html h

  class RollCallView extends BaseView
    el: $ "#main-activity"
    events:
      "click #btn-roll-call-present": "countryPresent"
      "click #btn-roll-call-absent":  "countryAbsent"
    initialize: ->
      @current = 0
      @countryList = Master.get 'countryList'
      Master.set 'presentList', []
      appView.disable 'btn-roll-call'
      super 'roll-call-view'
    render: ->
      if @current == @countryList.length
        @terminate()
      else
        h =  '<div class="highlight-country">' + this.countryList[this.current] + '</div>'
        h += '<button class="btn btn-success" id="btn-roll-call-present">' + $.t('rollCall.present') + ' (P)</button>'
        h += '<button class="btn btn-warning" id="btn-roll-call-absent">' + $.t('rollCall.absent') + ' (A)</button>'
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
      super()
      success $.t 'prompt.rollCallCompleted'
      appView.enable 'btn-roll-call'
      appView.enable 'btn-gsl'
      appView.enable 'btn-motion'

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
      timelineView.addTitle $.t 'log.sessionid', id: Master.get('sessionInfo').sessionid
      tlog 'initComplete'
      @$el.modal 'hide'

  class TimerView extends Backbone.View
    $t:  $ "#global-timer"
    $tt: $ "#global-timer-total"
    $timers: $ ".timer"
    el:  $ "#timer-wrapper"
    running: false
    events:
      "click #btn-timer-toggle": 'toggle'
      "click #btn-timer-reset" : 'reset'
      "timeout"                : 'toggle'
    initialize: ->
      @$timers.timer()
      @setStart()
      log '$ TimerView initialized.', DEBUG
    setStart: ->
      $("#btn-timer-toggle").html $.t 'btn.start'
    setTime: (t, tt) ->
      tt ?= t
      @$t.timer time:t
      @$tt.timer time:tt
    toggle: ->
      if @running
        @$timers.timer 'stop'
        @running = false
        $("#btn-timer-toggle").html  $.t 'btn.continue'
      else
        @$timers.timer 'start'
        @running = true
        $("#btn-timer-toggle").html  $.t 'btn.pause'
    reset: ->
      @toggle()  if @running
      @$t.timer 'reset'
      @setStart()
      log 'Global Timer reset', DEBUG
    resetAll: ->
      @toggle()  if @running
      @$timers.timer 'reset'
      @setStart()
      log 'Global Timer reset', DEBUG

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
        log $.t('log.sessionResumed'), PRODUCT
        return false
      else
        log $.t('log.sessionPaused'), PRODUCT
        bootbox.dialog '<span class="suspend-title">' + $.t('prompt.sessionSuspended') + '</span><hr>',
          [
            'label'   : $.t('prompt.sessionResume')
            'class'   : ''
            'callback': -> @togglePause
          ]
    initRollCall: ->
      @rollCallView = new RollCallView()
    initGeneralSL: ->
      @gsl = new SpeakersList()
      @gslView = new GSLView(model: @gsl)
    motionMC: ->
      _mv = @motionVote
      bootbox.dialog $("#tpl-init-mc").html(),
        [
            'label'   : $.t 'btn.cancel'
            'class'   : ''
            'callback': ->
              info $.t "mc.promptCancelled"
          ,
            'label'   : $.t 'btn.ok'
            'class'   : 'btn-primary'
            'callback': ->
              _mv $.t('motion.mc'), 'm1', ->
                log $("#init-mc-topic").val()
                @mcView = new MCView(
                  model: new SpeakersList,
                  topic     : $("#init-mc-topic").val()
                  time_tot  : $("#init-mc-total-time").val()
                  time_each : $("#init-mc-each-time").val()
                )
        ]
    motionUMC: ->
      _mv = @motionVote
      bootbox.prompt $.t('umc.promptTime'), (t) ->
        @motionVote $.t('motion.umc'), 'm1', ->
          @umcView = new UMCView(time: t)
    motionGSLTime: ->
      if not @gsl?
        error $.t 'error.noGSL'
        return
      _gsl = @gsl
      @motionVote $.t('motion.changeGSTime'), 'm1', ->
        bootbox.prompt $.t('changeGSTime.promptTime'), (t) ->
          _gsl.set 'time': t
          success $.t('changeGSTime.success', t: t)

    motionVote: (title, pass, callback) ->
      if not Master.get('sessionStats').cnt?
        error $.t 'error.initSessionFirst'
        return false
      if pass == 'm2'
        pass = Master.get('sessionStats').m2.value
      else if pass == 'm1'
        pass = Master.get('sessionStats').m1.value
      #else case number
      else
        pass = Master.get('sessionStats').m1.value
      bootbox.dialog "<div class=\"motion-title\">#{title}</div>#{$.t ('motion.promptBefore')} <code class=\"huge-number\">#{pass}</code> #{$.t ('motion.promptAfter')}",
        [
            'label'   : $.t 'btn.fail'
            'class'   : 'btn-warning'
            'callback': -> info $.t('motion.failBefore') + title + $.t('motion.failAfter')
          ,
            'label'   : $.t 'btn.pass'
            'class'   : 'btn-success'
            'callback': ->
              success info $.t('motion.passBefore') + title + $.t('motion.passAfter')
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
      Master.register @, $.t('idle.idle'), 'idle'
      @render()
    render: ->
      @$el.html $.t 'idle.msg'
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
    el: $ "#timeline"
    initialize: ->
      @render()
    add: (s) ->
      @$el.append '<li><a href="#">' + now() + ' ' + s + '</a></li>\n'
    addTitle: (s) ->
      @$el.append '<li class="nav-header">' + s + '</li>\n'
    render: ->
      log '$ TimelineView rendered', DEBUG

  class MasterControl extends Backbone.Model
    defaults:
      countryList: []
      presentList: []
      sessionStats: []
      sessionInfo: {}
      ongoing: null
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
      if not (old is null)
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
          key: $.t 'sessionInfo.cnt'
          value: p
        m1:
          key: $.t 'sessionInfo.m1'
          value: Math.floor(p / 2) + 1
        m2:
          key: $.t 'sessionInfo.m2'
          value: Math.floor(p * 2 / 3) + 1
        spm:
          key: $.t 'sessionInfo.spm'
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

  i18n.init
    ns: 'app'
    lng: 'zh-CN'
    debug: THRESHOLD >= DEBUG
    getAsync: false
    resGetPath: 'i18n/__lng__/__ns__.json'
  .done ->
    $('html').i18n();

  Master = new MasterControl()
  idleView = new IdleView()

  appView = new AppView()
  timelineView = new TimelineView()
  timerView = new TimerView()
  statsView = new StatsView()
  controlView = new ControlView()

  initModal = new InitModalView()
  settModal = new SettingsModalView()

  Master.trigger('change:variables')
  initModal.initSession()
  controlView.initRollCall()

  return