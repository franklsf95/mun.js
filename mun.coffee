DEBUG     = 0
PRODUCT   = 1
THRESHOLD = DEBUG

log = (s, lv) -> console.log s if lv >= THRESHOLD

warn = (s, type) ->
  con = "<div class=\"alert"
  con += " alert-" + type  if type
  con += "\">" + "<button class=\"close\" data-dismiss=\"alert\">&times;</button>"
  con += "<strong>Warning! </strong>"  unless type
  con += s + "</div>"
  $(con).prependTo($ "#main-container").hide().slideDown()

notice = (s, type) ->
  con = "<div class=\"alert"
  con += " alert-" + type  if type
  con += "\">" + "<button class=\"close\" data-dismiss=\"alert\">&times;</button>"
  con += "<strong>Warning! </strong>"  unless type
  con += s + "</div>"
  $(con).prependTo($ "#main-wrapper").hide().fadeIn()

now = ->
  t = new Date
  t.getHours() + ":" + t.getMinutes()

newModal = ->
  $theModal = $($("#tpl-init-sl").html().replace("\n", ""))
  $theModal.appendTo($("body")).attr("id", "modal-ha").modal "show"

jQuery ->
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

  class SLView extends Backbone.View
    el: $ "#main-activity"
    events:
      "keypress": 'enterKey'
      "click #btn-gsl-next": 'nextCountry'

    initialize: ->
      @listenTo @model, "change:list", @renderList
      @listenTo @model, "change:time", @renderTimer
      Master.register @, "General Speaker's List", 'gsl-view'

    render: ->
      country = @model.get('list')[@model.get 'current']
      country ?= ''
      content = "<div class=\"highlight-country\">#{country}</div>"
      content += '<hr>'
      content += '<input type="text" id="sl-add-country" data-placement="bottom" data-original-title="Enter to Add Country"><button id="btn-gsl-next" class="btn btn-primary">Next Speaker</button>'
      @$el.html content
      @renderList()
      @renderTimer()
      $("#sl-add-country").tooltip(trigger: 'focus').focus()
      @

    renderList: ->
      $(".pending-country-list").remove()
      list = @model.get 'list'
      content = '<ul class=\"pending-country-list\">'
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
      notice "General Speaker's List exhausted.", 'info'
      log 'GSLView terminated.', DEBUG

  class SettingsModalView extends Backbone.View
    el: $ "#modal-settings"
    events:
      "click #submit-global-settings": "saveGlobalSettings"
    initialize: ->
      log '$ SettingsModelView initialized.', DEBUG
    saveGlobalSettings: ->
      vars.key = $("#input-" + key).val() for key of Master.get 'variables'
      Master.set 'variables', vars

  class InitModalView extends Backbone.View
    el: $ "#modal-init"
    events:
      "click #submit-init": "initSession"
    initialize: ->
      log '$ InitModelView initialized.', DEBUG
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
      "click #btn-roll-call"        : "initRollCall"
      "click #btn-gsl"              : "initGeneralSL"
      "click #btn-motion-gsl-time"  : "motionGSLTime"
      "click #btn-motion-mc"        : "motionMC"
      "change #input-xml-log"       : "readXML"

    toggleFullscreen: ->
      if screenfull.enabled
        screenfull.toggle()
        $("#btn-toggle-fullscreen").html (if screenfull.isFullscreen then 'Exit Fullscreen' else 'Fullscreen Mode')

    initRollCall: ->
      @rollCallView = new RollCallView()

    initGeneralSL: ->
      @gsl = new SpeakersList()
      @gslView = new SLView(model: @gsl)

    motionMC: ->
      @mcsl = new SpeakersList()
      @mcView = new SLView(model: @mcsl)

    motionGSLTime: ->
      if not @gsl?
        notice "General Speaker's List must first be initialized!"
        return
      _gsl = @gsl
      bootbox.prompt "Enter new Speaking Time:", (t) ->
        _gsl.set 'time': t
        notice "General Speech's Time is changed to #{t} seconds.", 'success'

    readXML: (e) ->
      file = e.target.files[0]
      reader = new FileReader()
      reader.onloadend = ( (file)->
        (e) ->
          $("#xml-content").html e.target.result
      )(file)
      reader.readAsText file, 'UTF-8'

  class StatsView extends Backbone.View
    el: $ "#list-session-stats"
    initialize: ->
      @listenTo Master, 'change:sessionStats', @render
      log '$ StatsView initialized.', DEBUG
    render: ->
      @$el.html ''
      for key, value of Master.get 'sessionStats'
        @$el.append "<dt>#{key}</dt><dd>#{value}</dd>"
      @

  class IdleView extends Backbone.View
    el: $ "#main-activity"
    initialize: ->
      @render()
    render: ->
      @$el.html '<p>idle</p>'
      log 'IdleView rendered', DEBUG

  class MasterControl extends Backbone.Model
    defaults:
      countryList: []
      presentList: []
      sessionStats: {}
      sessionInfo: {}
      ongoing:
        view: new IdleView()
        name: 'idle'
        cls: 'idle'
      threadStack: []
      variables:
        globalPrompt: 'This is a development version of mun.js'

    initialize: ->
      @on 'change:presentList', @calculate
      @on 'change:variables', @applyVars
      @applyVars()
      log '@ Object MasterControl created.', DEBUG

    register: (_v, _n, _c) ->
      @get('threadStack').push @get('ongoing')
      @unregister @get('ongoing').cls #############
      @set 'ongoing',
        view: _v
        name: _n
        cls: _c
      @logStack false, _c
      _v.render()
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
        'Country Present': p
        'Simple Majority': Math.floor(p / 2) + 1
        'Absolute Majority': Math.floor(p * 2 / 3) + 1
        '20% Present Count': Math.round(p / 5)

    addPresentCountry: (c) ->
      @get('presentList').push c
      @trigger('change:presentList')

    applyVars: ->
      $("#global-prompt").html @get('variables').globalPrompt
      $("#input-global-prompt").val @get('variables').globalPrompt

    logStack: (isUnreg, cls) ->
      log ">>\tThread #{cls} " + (if isUnreg then 'popped out' else 'pushed in')
      log ">>\tThread Stack:"
      log "\t\t #{o.view}\t#{o.name}\t#{o.cls}", DEBUG  for o in @get('threadStack')
      return

  class AppView extends Backbone.View
    initialize: ->
      @listenTo Master, 'change:ongoing', @render
      @listenTo Master, 'change:sessionInfo', @renderTitle
      @render()
      log '$ AppView initialized.', DEBUG

      if not (window.File && window.FileReader && window.FileList && window.Blob)
        warn 'XML File Processing Function not available.'

    render: (name, cls) ->
      $("#main-activity-name").html Master.get('ongoing').name
      $("#main-wrapper").addClass Master.get('ongoing').cls

    unrender: (cls) ->
      $("main-wrapper").removeClass cls

    renderTitle: ->
      $("#title-committee").html  Master.get('sessionInfo')['committee']
      $("#title-abbr").html       Master.get('sessionInfo')['abbr']
      $("#title-sessionid").html  Master.get('sessionInfo')['sessionid']

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
  initModal.initSession()

  return