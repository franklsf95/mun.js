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
    to ?= '#main-container'
    con = '<div class="alert'
    con += ' alert-' + type  if type
    con += '"><button class="close" data-dismiss="alert">&times;</button>'
    con += "<strong>#{$.t('prompt.warning')}</strong>"  unless type
    con += s + '</div>'
    $(con).prependTo($ to).hide().slideDown()
    window.setTimeout ( -> $('.alert').alert('close') ), Master.get('variables').autoFadeTime

  notice = (s, type) -> warn s, type, '#main-wrapper'
  error   = (s) -> notice "<b>#{$.t('prompt.error')}</b>"   + s, 'error'
  success = (s) -> notice "<b>#{$.t('prompt.success')}</b>" + s, 'success'
  info    = (s) -> notice "<b>#{$.t('prompt.notice')}</b>"  + s, 'info'

  now = ->
    t = new Date
    min = t.getMinutes()
    min = '0' + min  if min < 10
    t.getHours() + ':' + min

  uid = -> new Date().getTime() % 1000000
  tpl = (id) -> $ $(id).html().replace('\n', '')
  tlog = (s, context) -> 
    timeline.add
      time: now()
      code: s
      msg:  $.t "log.#{s}", context

  class SpeakersList extends Backbone.Model
    defaults: ->  # fix bug that list[] is declared static in prototype
      list: []
      current: -1
      time: 120
    initialize: (arr) ->
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
      @get('list')[@get 'current']

  class BaseView extends Backbone.View
    el: $ '#main-activity'
    initialize: (c) ->
      @name = $.t "views.#{c}"
      @cls  = c
      Master.register @, @name, @cls
    terminate: ->
      Master.unregister @cls
      @undelegateEvents()
      log "$ #{@name} terminated.", DEBUG

  class BaseSLView extends BaseView
    events: ->
      'keypress': 'enterKey'
      'click #btn-gsl-next': 'nextCountry'
    initialize: (c) ->
      super c
      @listenTo @model, 'change:list', @renderList
    render: ->
      @$el.html ''
      @renderCurrent()
      @renderList()
      @renderTimer()
      $('#sl-add-country').tooltip
        trigger: 'focus'
      .typeahead
        source: -> Master.get 'presentList'
      .focus()
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
      $('.pending-country-list').html h
      @
    renderTimer: ->
      timerView.setTime @model.get 'time'
    enterKey: (e) ->
      if e.keyCode == 13
        c = $('#sl-add-country').val()
        @model.push c
        $('#sl-add-country').val('').focus()
    nextCountry: ->
      c = @model.next()
      if c?
        $('.highlight-country').html c
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
      @listenTo @model, 'change:time', @renderTimer

  class MCView extends BaseSLView
    events: ->
      _.extend {}, super, 'click #btn-exit-mc': 'terminate'
    initialize: (opt) ->
      @params = opt  # topic, time_tot, time_each
      super 'mc-view'
      appView.disable 'btn-motion'
    render: ->
      @$el.html "<div class=\"mc-title\">#{$.t('mc.topic')}#{@params.topic}</div><hr>"
      @renderCurrent()
      @renderList()
      @renderTimer()
      @$el.append '<hr><button class="btn btn-info" id="btn-exit-mc">' + $.t('mc.close') + '</button>'
      $('#sl-add-country').tooltip(trigger: 'focus').focus()
      @
    renderTimer: ->
      timerView.setTime @params.time_each, @params.time_tot
    terminate: ->
      super()
      # Rewrite the motion item
      _mc = timeline.pop()
      timeline.add new ItemSL
        time: _mc.get 'time'
        code: _mc.get 'code'
        msg:  _mc.get 'msg'
        sl:  @model.get 'list'
      log timeline
      appView.enable 'btn-motion'

  class UMCView extends BaseView
    events:
      'click #btn-exit-umc': 'terminate'
    initialize: (opt) ->
      super 'umc-view'
      appView.disable 'btn-motion'
      timerView.setTime opt.time
      @render()
    render: ->
      h =  "<div class=\"mc-title\">#{@name}</div>"
      h += '<button class="btn btn-info" id="btn-exit-umc">' + $.t('mc.close') + '</button>'
      @$el.html h
    terminate: ->
      super()
      tlog 'endUMC'
      appView.enable 'btn-motion'

  class RollCallView extends BaseView
    events:
      'click #btn-roll-call-present': 'countryPresent'
      'click #btn-roll-call-absent':  'countryAbsent'
    keys:
      'p': 'countryPresent'
      'a': 'countryAbsent'
    initialize: ->
      @current = 0
      @countryList = Master.get 'countryList'
      Master.set 'presentList', []
      appView.disable 'btn-roll-call'
      tlog 'rollCallStarted'
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
      tlog 'rollCallCompleted'
      appView.enable ['btn-roll-call', 'btn-gsl', 'btn-motion', 'btn-vote']

  class VoteView extends BaseView
    initialize: ->
      super 'vote-view'
      @render()
    render: ->
      @$el.html 'Hello!'

  class SettingsModalView extends Backbone.View
    el: $ '#modal-settings'
    events:
      'click #submit-global-settings': 'saveGlobalSettings'
    initialize: ->
      @listenTo Master, 'change:variables', @render
    render: ->
      vars = Master.get 'variables'
      $('#input-' + i).val vars[i]   for i of vars
      @
    saveGlobalSettings: ->
      vars = {}
      for key of Master.get 'variables'
        vars[key] = $('#input-' + key).val()
      Master.set 'variables', vars

  class InitModalView extends Backbone.View
    el: $ '#modal-init'
    events:
      'click #submit-init': 'initSession'
    initSession: ->
      clist = $('#init-country-list').val().split '\n'
      clist = _(clist).filter( (v) -> v != '' )
      Master.set
        'sessionInfo':
          'committee': $('#init-committee').val()
          'abbr': $('#init-abbr').val()
          'topic': $('#init-topic').val()
          'sessionid': $('#init-sessionid').val()
        'countryList':
          clist
      appView.enable 'btn-roll-call'
      log 'Session successfully initialized!', PRODUCT

      timelineView.addTitle $.t 'log.sessionid', id: Master.get('sessionInfo').sessionid
      tlog 'initCompleted'
      @$el.modal 'hide'

  class LoadModalView extends Backbone.View
    el: $ '#modal-load'
    events:
      'click #btn-load-logfile'   : 'readJSON'
      'click #btn-load-to-session': 'loadToSession'
    readJSON: ->
      url = $('#logfile-name').val()
      $.getJSON url, (data) ->
        $('#logfile-content').val JSON.stringify data, null, '\t'
    loadToSession: ->
      o = JSON.parse $('#logfile-content').val()
      for k of o
        Master.set k, o[k]
      appView.enable ['btn-gsl', 'btn-motion', 'btn-vote']
      @$el.modal 'hide'

  class TimerView extends Backbone.View
    $t:  $ '#global-timer'
    $tt: $ '#global-timer-total'
    $timers: $ '.timer'
    el:  $ '#timer-wrapper'
    running: false
    events:
      'click #btn-timer-toggle': 'toggle'
      'click #btn-timer-reset' : 'reset'
      'timeout'                : 'toggle'
    initialize: ->
      @$timers.timer()
      @setStart()
    setStart: ->
      $('#btn-timer-toggle').html $.t 'btn.start'
    setTime: (t, tt) ->
      tt ?= t
      @$t.timer time:t
      @$tt.timer time:tt
    toggle: ->
      if @running
        @$timers.timer 'stop'
        @running = false
        $('#btn-timer-toggle').html  $.t 'btn.continue'
      else
        @$timers.timer 'start'
        @running = true
        $('#btn-timer-toggle').html  $.t 'btn.pause'
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
    el: $ '#control-wrapper'
    events:
      'click #btn-toggle-fullscreen': 'toggleFullscreen'
      'click #btn-pause'            : 'pauseSession'
      'click #btn-roll-call'        : 'initRollCall'
      'click #btn-gsl'              : 'initGeneralSL'
      'click #btn-motion-mc'        : 'motionMC'
      'click #btn-motion-umc'       : 'motionUMC'
      'click #btn-motion-gsl-time'  : 'motionGSLTime'
      'click #btn-vote'             : 'initVote'
      # 'click #btn-load'             : 'openLoad'
      'click #btn-save'             : 'saveSession'
      'change #input-xml-log'       : 'readXML'
    toggleFullscreen: ->
      if screenfull.enabled
        screenfull.toggle()
        $('#btn-toggle-fullscreen').html (if screenfull.isFullscreen then 'Exit Fullscreen' else 'Fullscreen Mode')
    pauseSession: ->
      welcomeView.msg($.t 'welcome.paused').renderBtn($.t 'btn.resumeSession').render()
      log $.t('log.sessionPaused'), PRODUCT
    initRollCall: ->
      @rollCallView = new RollCallView()
    initGeneralSL: ->
      @gsl = new SpeakersList()
      @gslView = new GSLView(model: @gsl)
    motion: (opt) ->
      $m = tpl '#tpl-motion'
      mid = 'modal-' + uid()
      $m.appendTo($('body')).attr 'id', mid
      $('#motion-heading').html opt.title
      $('#add-here').prepend tpl opt.elem
      $m
    motionMC: ->
      mcModal = new MotionMCView
        el: @motion
          title: $.t 'motion.mc'
          elem: '#tpl-motion-mc'
    motionUMC: ->
      umcModal = new MotionUMCView
        el: @motion
          title: $.t 'motion.umc'
          elem: '#tpl-motion-umc'
    motionGSLTime: ->
      gslModal = new MotionChangeGSLTimeView
        el: @motion
          title: $.t 'motion.changeGSLTime'
          elem: '#tpl-motion-change-gsl-time'
    initVote: ->
      @voteView = new VoteView
    saveSession: ->
      session =
        countryList : Master.get 'countryList'
        presentList : Master.get 'presentList'
        sessionStats: Master.get 'sessionStats'
        sessionInfo : Master.get 'sessionInfo'
        variables   : Master.get 'variables'
      log encodeURIComponent JSON.stringify session
      uri = 'data:application/json;charset=utf8,' + encodeURIComponent JSON.stringify session, null, 4
      $('<a download="Session Save.json" href="' + uri + '">Download</a>').appendTo '#download-area'
    readXML: (e) ->
      file = e.target.files[0]
      reader = new FileReader()
      reader.onloadend = ( (file)->
        (e) ->
          $('#xml-content').html e.target.result
      )(file)
      reader.readAsText file, 'UTF-8'

  class MotionBase extends Backbone.View
    events:
      'click .motion-pass': 'pass'
      'click .motion-fail': 'fail'
    passVote: 'm1'
    initialize: ->
      @render()
    render: ->
      @$el.i18n()
      @$el.modal 'show'
      $('.xe').editable
        mode: 'inline'
      $('.motion-mc-pass-vote').html Master.get('sessionStats')[@passVote].value
    fail: ->
      info $.t('motion.failBefore') + $.t('motion.mc') + $.t('motion.failAfter')
      @destroy()
    destroy: ->
      @$el.modal 'hide'
      @$el.data('modal', null).remove()
      $('.modal-backdrop').remove()

  class MotionMCView extends MotionBase
    pass: ->
      c = $('#motion-country').html()
      t = $('#motion-mc-topic').html()
      tlog 'motionMC',
        country: c
        topic  : t
      @mcView = new MCView
        model: new SpeakersList,
        topic     : t
        time_tot  : $('#motion-mc-total-time').html()
        time_each : $('#motion-mc-each-time').html()
      @mcView.model.push c
      success $.t('motion.passBefore') + $.t('motion.mc') + $.t('motion.passAfter')
      @destroy()

  class MotionUMCView extends MotionBase
    pass: ->
      tlog 'motionUMC',
        country: $('#motion-country').html()
      @umcView = new UMCView
        time: $('#motion-umc-time').html()
      success $.t('motion.passBefore') + $.t('motion.umc') + $.t('motion.passAfter')
      @destroy()

  class MotionChangeGSLTimeView extends MotionBase
    render: ->
      super()
      if not controlView.gsl?
        @$el.modal 'hide'
        error $.t 'error.noGSL'
        return
    pass: ->
      t = $('#motion-gsl-time').html()
      controlView.gsl.set 'time': t
      success $.t('changeGSLTime.success', t: t)
      @destroy()

  class StatsView extends Backbone.View
    el: $ '#dl-session-stats'
    initialize: ->
      @listenTo Master, 'change:sessionStats', @render
    render: ->
      @$el.html ''
      arr = Master.get 'sessionStats'
      for i of arr
        @$el.append "<dt>#{arr[i].key}</dt><dd>#{arr[i].value}</dd>"
      @

  class IdleView extends Backbone.View
    el: $ '#main-activity'
    initialize: ->
      Master.register @, $.t('idle.idle'), 'idle'
      @render()
    render: ->
      @$el.html $.t 'idle.msg'

  class Item extends Backbone.Model
    defaults: ->
      code: ''
      msg:  ''
      time: ''
      type: 'session'
    toString: ->
      @get('time') + ' ' + @get('msg')

  class ItemSL extends Item
    defaults: ->
      code: ''
      msg:  ''
      time: ''
      type: 'sl'
      sl:   []
    initialize: ->
      con = ''
      for e in @get 'sl'
        con += "<li>#{e}</li>"
      @set 'content', con
      @set 'title',   'Speakers List'

  class Timeline extends Backbone.Collection
    model: Item

  class TimelineView extends Backbone.View
    el: $ '#timeline'
    events:
      'click li': (e) ->
        $(e.target).popover 'toggle'
          html: true
    initialize: ->
      @listenTo timeline, 'add', @add
      @listenTo timeline, 'remove', @remove
      @render()
    add: (item) ->
      if item instanceof ItemSL
        s = '<li><a href="#" data-placement="right" '
        s += "data-content=\"#{item.get('content')}\" data-original-title=\"#{item.get('title')}\">"
        s += item + '</a></li>\n'
        @$el.append s
      else
        @$el.append '<li><a href="#">' + item + '</a></li>\n'
    addTitle: (s) ->
      @$el.append '<li class="nav-header">' + s + '</li>\n'
    remove: ->
      $('#timeline li').last().remove()

  class WelcomeView extends Backbone.View
    el: $ '#welcome-container'
    message: -> $.t 'prompt.defaultGlobal'
    events:
      'click #btn-welcome-hide': 'unrender'
    initialize: ->
      @render()
    render: ->
      @$el.fadeIn 1000
      $('#welcome-title').html @message
      log 'WelcomeView entered', DEBUG
    unrender: ->
      @$el.fadeOut 1000
      log 'WelcomeView exited', DEBUG
    msg: (s) ->
      @message = s
      @
    renderBtn: (s) ->
      $('#btn-welcome-hide').html s
      @

  class MasterControl extends Backbone.Model
    defaults:
      countryList: []
      presentList: []
      sessionStats: []
      sessionInfo: {}
      ongoing: null
      threadStack: []
      variables:
        autoFadeTime: 3000
        mcDefaultTimeTotal: 300 # not-used yet
        mcDefaultTimeEach: 60   # not-used yet
    initialize: ->
      @on 'change:presentList', @calculate
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
      log ">> Thread #{cls} " + (if isUnreg then 'popped out' else 'pushed in')
      if @get('threadStack').length == 0
        log '>> Thread Stack is empty.'
        return
      log '>> Thread Stack:'
      log "\t\t#{o.name}\t#{o.cls}", DEBUG  for o in @get 'threadStack'

  class AppView extends Backbone.View
    initialize: ->
      @listenTo Master, 'change:ongoing', @render
      @listenTo Master, 'change:variables', @renderVars
      @listenTo Master, 'change:sessionInfo', @renderTitle
      @render()
      # start self-inspection
      if not (window.File && window.FileReader && window.FileList && window.Blob)
        warn 'XML File Processing Function not available.'
    render: (name, cls) ->
      $('#main-activity-name').html Master.get('ongoing').name
      $('#main-wrapper').addClass Master.get('ongoing').cls
    unrender: (cls) ->
      $('#main-wrapper').removeClass cls
      $('#main-activity').html ''
    renderTitle: ->
      s = Master.get 'sessionInfo'
      h = '<span id="session-id">'
      h += $.t 'log.sessionid', id: s.sessionid
      h += '</span>'
      h += '<span id="session-topic">'
      h += s.topic
      h += '</span>'
      $('#session-title').html h
      h = s.committee + " (#{s.abbr})"
      $('#committee').html h
    renderVars: ->
      vars = Master.get('variables')
      log '> Global variables applied.', DEBUG
    enable: (arr) ->
      if $.isArray arr
        @_enable i for i in arr
      else
        @_enable arr
    _enable: (id) ->
      $('#' + id).removeAttr 'disabled'
      log id + ' enabled', DEBUG
    disable: (id) ->
      $('#' + id).attr 'disabled', true
      log id + ' disabled', DEBUG

  i18n.init
    ns: 'app'
    # lng: 'zh-CN'
    debug: THRESHOLD >= DEBUG
    getAsync: false
    resGetPath: 'i18n/__lng__/__ns__.json'
  .done ->
    $('html').i18n();

  Master = new MasterControl()
  idleView = new IdleView()
  welcomeView = new WelcomeView()

  timeline = new Timeline()
  appView = new AppView()
  timelineView = new TimelineView()

  timerView = new TimerView()
  statsView = new StatsView()
  controlView = new ControlView()
  initModal = new InitModalView()
  settModal = new SettingsModalView()
  loadModal = new LoadModalView()

  $('.xe').editable
    mode: 'inline'

  Master.trigger('change:variables')
  initModal.initSession()
  welcomeView.unrender()
  $('#modal-load').modal 'show'
  loadModal.readJSON()

  return