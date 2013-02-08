$(function() {
    var ControlView = Backbone.View.extend({
        el: $("#control-wrapper"),
        initialize: function() {

        },
        events: {
            "click #btn-toggle-fullscreen": "toggleFullscreen",
            "change #input-xml-log": "readXMLFile"
        },
        toggleFullscreen: function() {
            if (screenfull.enabled) {
                screenfull.toggle();
            }
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
            appConfig.set('globalPrompt', $("#input-global-prompt").val());
        }
    });

    var AppConfig = Backbone.Model.extend({
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

    var AppView = Backbone.View.extend({
        initialize: function() {

            //initialize XML FileReader
            if (!(window.File && window.FileReader && window.FileList && window.Blob)) {
                warn('XML File Processing Function not available.');
            }
        }
    });
    var appConfig = new AppConfig();

    var controlView = new ControlView();
    var settingsView = new SettingsView();
    var appView = new AppView();
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