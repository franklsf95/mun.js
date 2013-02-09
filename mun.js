$(function() {
    var DEBUG = 0;

    var RollCallView = Backbone.View.extend({
        el: $("#main-activity"),
        initialize: function() {
            this.render();
            log('Roll Call View initialized.', DEBUG);
        },
        render: function() {
            this.$el.html('<h1>Roll Call</h1>');
            Backbone.$("#main-wrapper").removeClass("span6").addClass("span9");
            Backbone.$("#sidebar-wrapper").hide();
        }
    });

    var ControlView = Backbone.View.extend({
        el: $("#control-wrapper"),
        initialize: function() {

        },
        events: {
            "click #btn-toggle-fullscreen": "toggleFullscreen",
            'click #btn-roll-call': "launchRollCall",
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
            sessionController.set('ongoing', 'Roll Call');
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

    var SettingsView = Backbone.View.extend({
        el: $("#modal-settings"),
        events: {
            "click #submit-global-settings": "saveGlobalSettings"
        },
        saveGlobalSettings: function() {
            settingsController.set('globalPrompt', $("#input-global-prompt").val());
        }
    });

    var SettingsController = Backbone.Model.extend({
        initialize: function() {
            this.initializeGlobal();
            this.on("change", this.initializeGlobal);
        },
        defaults: {
            'globalPrompt': 'This is a development version of mun.js'
        },
        initializeGlobal: function() {
            log(this);
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
            'ongoing': 'idle'
        },
        initialize: function() {
            this.on("change:presentList", this.calculate);
        },
        calculate: function() {
            var present = this.get('presentList').length;
            this.set('sessionStats', {
                'Countries Present': present,
                'Simple Majority': Math.floor(present / 2) + 1,
                'Absolute Majority': Math.floor(present * 2 / 3) + 1,
                '20% Present Count': Math.round(present / 5)
            });
        }
    });

    var StatsView = Backbone.View.extend({
        el: $("#list-session-stats"),
        initialize: function(){
            this.listenTo(sessionController, "change:sessionStats", this.render);
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

    var InitView = Backbone.View.extend({
        el: $("#modal-init"),
        events: {
            "click #submit-init": "initializeSession"
        },
        initialize: function(){
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
                    'abbreviation': $("#init-abbr").val(),
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
            this.render();
            //initialize XML FileReader
            if (!(window.File && window.FileReader && window.FileList && window.Blob)) {
                warn('XML File Processing Function not available.');
            }
        },
        render: function() {
            $("#main-activity-name").html(sessionController.get("ongoing"));
        },
        enable: function(id) {
            $('#' + id).removeAttr('disabled');
            log(id + ' enabled', DEBUG);
        },
        disable: function(id) {
            $('#' + id).attr('disabled', 1);
            log(id + ' disabled', DEBUG);
        }
    });
    var settingsController = new SettingsController();
    var sessionController = new SessionController();

    var statsView = new StatsView();
    var controlView = new ControlView();
    var initView = new InitView();
    var settingsView = new SettingsView();
    var appView = new AppView();

    sessionController.set('presentList', ['China', 'France', 'Russia', 'USA', 'UK'] );
});


function log(str, level) {
    console.log(str);
}

function warn(s) {
    var con = '<div class="alert">'+
        '<button class="close" data-dismiss="alert">&times;</button>'+
        '<strong>Warning! </strong>' + s +
        '</div>';
    $("#main-container").prepend(con);
}