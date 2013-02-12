$(function() {
    var DEBUG = 0, PRODUCT = 1;

    var SpeakersList = Backbone.Model.extend({
        defaults: {
            'list': [],
            'current': 0
        },
        initialize: function() {
            log('\tSpeakersList created.', DEBUG);
        }
    });

    var GSLView = Backbone.View.extend({
        el: $("#main-activity"),
        initialize: function() {
            var gsl = new SpeakersList();
            sessionController.register("General Speaker's List", 'gsl-view');
        }
    });

    var RollCallView = Backbone.View.extend({
        el: $("#main-activity"),
        events: {
            "click #btn-roll-call-present": "countryPresent",
            "click #btn-roll-call-absent":  "countryAbsent"
        },
        current: 0,
        countryList: [],
        initialize: function() {
            this.countryList = sessionController.get('countryList');
            sessionController.register('Roll Call', 'roll-call-view');
            this.render();
            log('RollCallView initialized.', DEBUG);
        },
        render: function() {
            var content;
            if (this.current == this.countryList.length) {
                this.terminate();
            } else {
                content = '<div class="roll-call-current">' + this.countryList[this.current] + '</div>';
                content += '<button class="btn btn-success" id="btn-roll-call-present">Present (P)</button><button class="btn btn-warning" id="btn-roll-call-absent">Absent (A)</button>';
                content += '<ul>';
                var more = true;
                for (var i = this.current + 1; i < this.current + 5; i++ ) {
                    if (i == this.countryList.length) {
                        more = false;
                        break;
                    }
                    content += '<li class="roll-call-country">' + this.countryList[i] + '</li>';
                }
                if (more) content += '<li>...</li>';
                content += '</ul>';
            }
            this.$el.html(content);//.focus();
            return this;
        },
        countryPresent: function() {
            log(this.countryList[this.current] + ' is present.', PRODUCT);
            sessionController.addPresentCountry(this.countryList[this.current]);
            this.current++;
            this.render();
        },
        countryAbsent: function() {
            log(this.countryList[this.current] + ' is absent.', PRODUCT);
            this.current++;
            this.render();
        },
        terminate: function() {
            Backbone.$("#main-wrapper").removeClass("roll-call-view");
            sessionController.set('ongoing', 'idle');
            this.$el.html('');
            notice('Roll Call completed.', 'success');
            log('RollCallView terminated.', DEBUG);
        }
    });

    var TimerView = Backbone.View.extend({
        $etimer: $("#global-timer"),
        el: $("#timer-wrapper"),
        running: false,
        events: {
            "click #btn-timer-toggle": "toggle",
            "click #btn-timer-reset": "reset"
        },
        initialize: function() {
            this.$etimer.timer({
                time: 8
            });
            log('TimerView initialized.', DEBUG);
        },
        toggle: function() {
            if (this.running) {
                this.$etimer.timer('stop');
                this.running = false;
                $("#btn-timer-toggle").html("Continue");
            } else {
                this.$etimer.timer('start');
                $("#btn-timer-toggle").html("Pause");
                this.running = true;
            }
        },
        reset: function() {
            this.$etimer.timer('reset');
            log('Timer reset', DEBUG);
        }
    });

    var ControlView = Backbone.View.extend({
        el: $("#control-wrapper"),
        initialize: function() {
            log('ControlView initialized.', DEBUG);
        },
        events: {
            "click #btn-toggle-fullscreen": "toggleFullscreen",
            "click #btn-roll-call": "launchRollCall",
            "click #btn-gsl": "openGSL",
            "change #input-xml-log": "readXMLFile"
        },
        toggleFullscreen: function() {
            if (screenfull.enabled) {
                screenfull.toggle();
                if (screenfull.isFullscreen) {
                    $("#btn-toggle-fullscreen").html("Exit Fullscreen");
                } else {
                    $("#btn-toggle-fullscreen").html("Fullscreen Mode");
                }
            }
        },
        launchRollCall: function() {
            var rollCallView = new RollCallView();
        },
        openGSL: function() {
            var gslView = new GSLView();
        },
        readXMLFile: function(e) {
            var file = e.target.files[0];
            var reader = new FileReader();
            reader.onloadend = (function(f) {
                return function(e) {
                    var x = e.target.result;
                    $("#xml-content").html(x);
                };
            })(file);
            reader.readAsText(file, "UTF-8");
        }
    });

    var SettingsController = Backbone.Model.extend({
        initialize: function() {
            this.initializeGlobal();
            this.on("change", this.initializeGlobal);
            log('\tSettingsController created.', DEBUG);
        },
        defaults: {
            'globalPrompt': 'This is a development version of mun.js'
        },
        initializeGlobal: function() {
            $("#global-prompt").html(this.get('globalPrompt'));
            //write to config modal
            $("#input-global-prompt").val(this.get('globalPrompt'));
        }
    });

    var SessionController = Backbone.Model.extend({
        defaults: {
            'countryList': [],
            'presentList': [],
            'sessionStats': {},
            'sessionInfo': {},
            'ongoing': 'idle',
            'ongoingClass': '',
            'threadStack': []
        },
        initialize: function() {
            this.on("change:presentList", this.calculate);
            log('\tSessionController created.', DEBUG);
        },
        register: function(name, cls) {
            this.get('threadStack').push( new Array(this.get('ongoing'), this.get('ongoingClass')) );
            log(this.get('threadStack'), DEBUG);
            this.set({'ongoing': name, 'ongoingClass': cls});
        },
        calculate: function() {
            var present = this.get('presentList').length;
            this.set('sessionStats', {
                'Countries Present': present,
                'Simple Majority': Math.floor(present / 2) + 1,
                'Absolute Majority': Math.floor(present * 2 / 3) + 1,
                '20% Present Count': Math.round(present / 5)
            });
        },
        addPresentCountry: function(country) {
            this.get('presentList').push(country);
            this.trigger("change:presentList"); // workaround for pushing an element != change an array
        }
    });

    var StatsView = Backbone.View.extend({
        el: $("#list-session-stats"),
        initialize: function(){
            this.listenTo(sessionController, "change:sessionStats", this.render);
            log('StatsView initialized.', DEBUG);
        },
        render: function(){
            this.$el.html("");
            var stats = sessionController.get('sessionStats');
            for (var key in stats) {
                var str = "<dt>" + key + "</dt>\n<dd>" + stats[key] + "</dd>";
                this.$el.append(str);
            }
            return this;
        }
    });

    var SettingsModelView = Backbone.View.extend({
        el: $("#modal-settings"),
        initialize: function() {
            log('SettingsModelView initialized.', DEBUG);
        },
        events: {
            "click #submit-global-settings": "saveGlobalSettings"
        },
        saveGlobalSettings: function() {
            settingsController.set('globalPrompt', $("#input-global-prompt").val());
        }
    });

    var InitModelView = Backbone.View.extend({
        el: $("#modal-init"),
        events: {
            "click #submit-init": "initializeSession"
        },
        initialize: function(){
            log('InitModelView initialized.', DEBUG);
            //this.listenTo(sessionController, "change:sessionInfo change:countryList", this.render);
        },
        render: function(){
            return this;
        },
        initializeSession: function() {
            var clist = $("#init-country-list").val().split('\n');
            clist = _(clist).filter( function(v) {return v !== '';});
            sessionController.set( {
                'sessionInfo': {
                    'committee': $("#init-committee").val(),
                    'abbr': $("#init-abbr").val(),
                    'topic': $("#init-topic").val(),
                    'sessionid': $("#init-sessionid").val()
                    },
                'countryList': clist
            });
            appView.enable("btn-roll-call");
        }
    });

    var AppView = Backbone.View.extend({
        initialize: function() {
            this.listenTo(sessionController, "change:ongoing change:ongoingClass", this.render);
            this.listenTo(sessionController, "change:sessionInfo", this.renderTitle);
            this.render();
            //initialize XML FileReader
            log('AppView initialized.', DEBUG);
            if (!(window.File && window.FileReader && window.FileList && window.Blob)) {
                warn('XML File Processing Function not available.');
            }
        },
        render: function() {
            $("#main-activity-name").html(sessionController.get("ongoing"));
            $("#main-wrapper").addClass(sessionController.get("ongoingClass"));
            //log(sessionController.get("threadStack"), DEBUG);
        },
        renderTitle: function() {
            $("#title-committee").html(sessionController.get('sessionInfo')['committee']);
            $("#title-abbr").html(sessionController.get('sessionInfo')['abbr']);
            $("#title-sessionid").html(sessionController.get('sessionInfo')['sessionid']);
        },
        enable: function(id) {
            $('#' + id).removeAttr('disabled');
            log(id + ' enabled', DEBUG);
        },
        disable: function(id) {
            $('#' + id).attr('disabled', 1);
            log(id + ' disabled', DEBUG);
        },
        enlarge: function() {
            $("#main-wrapper").removeClass("span6").addClass("span9");
            $("#sidebar-wrapper").hide();
        }
    });
    var settingsController = new SettingsController();
    var sessionController = new SessionController();

    var timerView = new TimerView();
    var statsView = new StatsView();
    var controlView = new ControlView();
    var initView = new InitModelView();
    var settingsView = new SettingsModelView();
    var appView = new AppView();
    //warn('mun.js successfully initialized!', 'success');

    initView.initializeSession();
    controlView.launchRollCall();
});


function log(str, level) {
    console.log(str);
}

function warn(s, type) {
    var con = '<div class="alert';
    if (type) con += ' alert-' + type;
    con += '">' +
        '<button class="close" data-dismiss="alert">&times;</button>';
    if (!type) con += '<strong>Warning! </strong>';
    con += s + '</div>';
    $(con).prependTo($("#main-container")).hide().slideDown();
}

function notice(s, type) {
    var con = '<div class="alert';
    if (type) con += ' alert-' + type;
    con += '">' +
        '<button class="close" data-dismiss="alert">&times;</button>';
    if (!type) con += '<strong>Warning! </strong>';
    con += s + '</div>';
    $(con).prependTo($("#main-wrapper")).hide().fadeIn();
}