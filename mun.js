$(function() {
    var DEBUG = 0, PRODUCT = 1;

    var SpeakersList = Backbone.Model.extend({
        defaults: {
            'list': [],
            'current': -1,
            'time': 120
        },
        initialize: function(arr) {
            log('@ Object SpeakersList created.', DEBUG);
            if (arr !== undefined)
                this.set('list', arr);
        },
        push: function(s) {
            if (s === '' || s === null || s === undefined) return this;
            this.get('list').push(s);
            this.trigger('change:list');
            return this;
        },
        next: function() {
            if (this.get('current') == this.get('list').length - 1)
                return -1;
            this.set('current', this.get('current') + 1);
            return this.get('list')[this.get('current')];
        }
    });

    var GSLView = Backbone.View.extend({
        el: $("#main-activity"),
        events: {
            "keypress": "enterHandler",
            "click #btn-gsl-next": "nextCountry"
        },
        initialize: function() {
            this.listenTo(this.model, 'change:list', this.renderList);
            this.listenTo(this.model, 'change:time', this.renderTimer);
            sessionController.register(this, "General Speaker's List", 'gsl-view');

            
        },
        render: function() {
            var country = this.model.get('list')[this.model.get('current')];
            if (country === undefined) {
                country = '';
            }
            var content = '<div class="highlight-country">' + country + '</div>';
            content += '<hr>';
            content += '<input type="text" id="sl-add-country" data-placement="bottom" data-original-title="Enter to Add Country"><button id="btn-gsl-next" class="btn btn-primary">Next Speaker</button>';
            this.$el.html(content);
            this.renderList();
            this.renderTimer();
            $("#sl-add-country").tooltip({'trigger': 'focus'}).focus();
            return this;
        },
        renderList: function() {
            $(".pending-country-list").remove();
            var list = this.model.get('list');
            var content = '<ul class="pending-country-list">';
            for (var i = this.model.get('current') + 1; i < list.length; i++) {
                content += '<li>' + list[i] + '</li>';
            }
            content += '</ul>';
            this.$el.append(content);
            return this;
        },
        renderTimer: function() {
            timerView.setTime(this.model.get('time'));
        },
        enterHandler: function(e) {
            if (e.keyCode == 13) {
                var country = $("#sl-add-country").val();
                this.model.push(country);
                $("#sl-add-country").val("").focus();
            }
        },
        nextCountry: function() {
            var c = this.model.next();
            if (c == -1) {
                this.terminate();
            } else {
                $(".highlight-country").html(c);
                this.renderList();
                timerView.reset();
                return this;
            }
        },
        terminate: function() {
            sessionController.unregister('gsl-view');
            notice('General Speaker\'s List exhausted.', 'info');
            log('GSLView terminated.', DEBUG);
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
            sessionController.register(this, 'Roll Call', 'roll-call-view');
            log('$ RollCallView initialized.', DEBUG);
        },
        render: function() {
            var content;
            if (this.current == this.countryList.length) {
                this.terminate();
            } else {
                content = '<div class="highlight-country">' + this.countryList[this.current] + '</div>';
                content += '<button class="btn btn-success" id="btn-roll-call-present">Present (P)</button><button class="btn btn-warning" id="btn-roll-call-absent">Absent (A)</button>';
                content += '<ul class="pending-country-list">';
                var more = true;
                for (var i = this.current + 1; i < this.current + 5; i++ ) {
                    if (i == this.countryList.length) {
                        more = false;
                        break;
                    }
                    content += '<li>' + this.countryList[i] + '</li>';
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
            sessionController.unregister('roll-call-view');
            notice('Roll Call completed.', 'success');
            log('RollCallView terminated.', DEBUG);
        }
    });

    var IdleView = Backbone.View.extend({
        el: $("#main-activity"),
        initialize: function() {
            this.render();
        },
        render: function() {
            log("IdleView rendered.", DEBUG);
            this.$el.html('<p>idle</p>');
            return this;
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
            this.$etimer.timer();
            this.setStart();
            log('$ TimerView initialized.', DEBUG);
        },
        setStart: function() {
            $("#btn-timer-toggle").html("Start");
        },
        setTime: function(t) {
            this.$etimer.timer({time: t});
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
            if (this.running) this.toggle();
            this.$etimer.timer('reset');
            this.setStart();
            log('Timer reset', DEBUG);
        }
    });

    var ControlView = Backbone.View.extend({
        el: $("#control-wrapper"),
        initialize: function() {
            log('$ ControlView initialized.', DEBUG);
        },
        events: {
            "click #btn-toggle-fullscreen": "toggleFullscreen",
            "click #btn-roll-call": "launchRollCall",
            "click #btn-gsl": "openGSL",
            "click #btn-motion-gsl-time": "motionGSLTime",
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
            this.rollCallView = new RollCallView();
        },
        openGSL: function() {
            this.gsl = new SpeakersList();
            this.gslView = new GSLView({model: this.gsl});
        },
        motionGSLTime: function() {
            //motion gatekeeper
            if (this.gsl === undefined) {
                notice("General Speaker's List must first be initialized!");
                return;
            }
            var _gsl = this.gsl;
            bootbox.prompt("Enter new speaking time:", function(t) {
                _gsl.set('time', t);
                notice("General Speech's Time is changed to " + t + " seconds.", 'success');
            });
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
            log('@ Object SettingsController created.', DEBUG);
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
            'ongoing': {
                view: new IdleView(),
                name: 'idle',
                cls: 'idle'
            },
            'threadStack': []
        },
        initialize: function() {
            this.on("change:presentList", this.calculate);
            log('@ Object SessionController created.', DEBUG);
        },
        register: function(view, name, cls) {
            this.get('threadStack').push( this.get('ongoing') );
            this.unregister(this.get('ongoing').cls); //?? is this really necessary??
            this.set('ongoing', {
                'view': view,
                'name': name,
                'cls': cls
            });
            this.logStack(0, cls);
            view.render();
            return this;
        },
        unregister: function(cls) {
            if (this.get('ongoing').cls != cls || cls == 'idle')
                return this;

            appView.unrender(cls);
            var old = this.get('threadStack').pop();
            this.set('ongoing', {
                'view': old.view,
                'name': old.name,
                'cls': old.cls
            });
            old.view.render();
            this.logStack(1, cls);
            return this;
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
        },
        logStack: function(unreg, cls) {
            log('>>\tThread ' + cls + (unreg ? ' popped out' : ' pushed in.'));
            log('>>\tThread Stack:');
            _(this.get('threadStack')).each( function(o) {
                log('\t\t' + o.view + '\t' + o.name + '\t' + o.cls, DEBUG);
            });
        }
    });

    var StatsView = Backbone.View.extend({
        el: $("#list-session-stats"),
        initialize: function(){
            this.listenTo(sessionController, "change:sessionStats", this.render);
            log('$ StatsView initialized.', DEBUG);
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
            log('$ SettingsModelView initialized.', DEBUG);
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
            log('$ InitModelView initialized.', DEBUG);
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
            this.listenTo(sessionController, "change:ongoing", this.render);
            this.listenTo(sessionController, "change:sessionInfo", this.renderTitle);
            this.render();
            //initialize XML FileReader
            log('$ AppView initialized.', DEBUG);
            if (!(window.File && window.FileReader && window.FileList && window.Blob)) {
                warn('XML File Processing Function not available.');
            }
        },
        render: function(name, cls) {
            $("#main-activity-name").html(sessionController.get('ongoing').name);
            $("#main-wrapper").addClass(sessionController.get('ongoing').cls);
        },
        unrender: function(cls) {
            $("#main-wrapper").removeClass(cls);
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
    //warn('$ mun.js successfully initialized.', 'success');

    initView.initializeSession();
    // controlView.openGSL();
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

function now() {
    var t = new Date();
    return t.getHours() + ':' + t.getMinutes();
}

function newModal() {
    $theModal = $( $("#tpl-init-sl").html().replace('\n', '') );
    $theModal.appendTo($("body")).attr("id", "modal-ha").modal('show');
}