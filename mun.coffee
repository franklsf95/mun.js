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
    defaults:
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
      country = @model.get('list')[@model.get 'current']
      country ?= ''
      content = "<div class=\"highlight-country\">#{country}</div>"
      content += '<hr>'
      content += '<input type="text" id="sl-add-country" data-placement="bottom" data-original-title="Enter to Add Country">'
      content += '<button id="btn-gsl-next" class="btn btn-primary">Next Speaker</button>'
      @$el.html content
      @renderList()
      @renderTimer()
      $("#sl-add-country").tooltip(trigger: 'focus').focus()
      @
    renderList: ->
      $(".pending-country-list").remove()
      list = @model.get 'list'
      content = '<ul class="pending-country-list">'
      content += "<li>#{c}</li>"  for c in list[@model.get('current') + 1 ..]
      content += "</ul>"
      @$el.append content
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
      Master.unregister 'gsl-view'
      @undelegateEvents()
      notice @name + " exhausted.", 'info'
      log @name + ' terminated.', DEBUG

  class GSLView extends BaseSLView
    initialize: ->
      super("General Speaker's List", 'gsl-view')
      log '\t$ GSLView initialized.', DEBUG

  class MCView extends BaseSLView
    initialize: ->
      super("Moderacted Caucus", 'mc-view')
      log '\t$ MCView initialized.', DEBUG

  class RollCallView extends Backbone.View
    el: $ "#main-activity"
    events:
      "click #btn-roll-call-present": "countryPresent"
      "click #btn-roll-call-absent":  "countryAbsent"
    current: 0
    countryList: [],
    className: 'roll-call-view'
    initialize: ->
      @countryList = Master.get 'countryList'
      Master.register @, 'Roll Call', @className
      Master.set 'presentList', []
      log '$ RollCallView initialized.', DEBUG
    render: ->
      if @current == @countryList.length
        @terminate()
      else
        content = '<div class="highlight-country">' + this.countryList[this.current] + '</div>'
        content += '<button class="btn btn-success" id="btn-roll-call-present">Present (P)</button>'
        content += '<button class="btn btn-warning" id="btn-roll-call-absent">Absent (A)</button>'
        content += '<ul class="pending-country-list">'
        content += "<li>#{c}</li>" for c in @countryList[@current + 1 .. @current + 5]
        content += '<li>...</li>'  if @current + 5 < @countryList.length
        content += '</li>'
      @$el.html content
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

  class TimerView extends Backbone.View
    $et: $ "#global-timer"
    el: $ "#timer-wrapper"
    running: false
    events:
      "click #btn-timer-toggle": 'toggle'
      "click #btn-timer-reset": 'reset'
    initialize: ->
      @$et.timer()
      @setStart()
      log '$ TimerView initialized.', DEBUG
    setStart: ->
      $("#btn-timer-toggle").html "Start";
    setTime: (t) ->
      @$et.timer time:t
    toggle: ->
      if @running
        @$et.timer 'stop'
        @running = false
        $("#btn-timer-toggle").html "Continue"
      else
        @$et.timer 'start'
        @running = true
        $("#btn-timer-toggle").html "Pause"
    reset: ->
      @toggle()  if @running
      @$et.timer 'reset'
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
        @mcsl = new SpeakersList()
        @mcView = new GSLView(model: @mcsl)
    motionGSLTime: ->
      if not @gsl?
        error "General Speaker's List must first be initialized!"
        return
      _gsl = @gsl
      @motionVote "Motion to Change General Speaking Time", 'm1', ->
        bootbox.prompt "Enter new Speaking Time:", (t) ->
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
      bootbox.dialog "<span class=\"motion-title\">#{title}</span>This motion needs <code class=\"huge-number\">#{pass}</code> votes in favor to pass.",
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
      paused: false
    initialize: ->
      @on 'change:presentList', @calculate
      log '@ Object MasterControl created.', DEBUG
    register: (v, n, c) ->
      @get('threadStack').push @get('ongoing')
      appView.unrender  @get('ongoing').cls
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
      last = @get('threadStack').pop()
      @set 'ongoing',
        view: last.view
        name: last.name
        cls: last.cls
      last.view.render()
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

  return