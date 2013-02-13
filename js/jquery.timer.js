(function($) {
    var time, now, el, threadHandler, timings;
    var methods = {
        init: function(options) {
            time = now = options.time;
            timings = options.timings;
            render();
        },
        start: function() {
            threadHandler = setInterval(function() {
                now--;
                if (now === 0)
                    methods.stop();
                render();
            }, 1000);
            return this;
        },
        stop: function() {
            clearInterval(threadHandler);
            return this;
        },
        reset: function() {
            clearInterval(threadHandler);
            now = time;
            render();
            return this;
        }
    };
    var render = function() {
        var _now = now;
        var hours = Math.floor(_now / 3600);
        _now %= 3600;
        var minutes = Math.floor(_now / 60);
        var seconds = _now % 60;
        var str = '';
        if (hours > 0) str += hours + ':';
        str += minutes + ':';
        if (seconds < 10) str += '0';
        str += seconds;
        el.html(str);

        for (var t in timings) {
            if (now == t) {
                var cmd = timings[t];
                if (typeof cmd == 'string') {
                    el.addClass(cmd);
                } else {
                    for (var prop in cmd) {
                        el.css(prop, cmd[prop]);
                    }
                }
                break;
            }
        }
    };

    $.fn.timer = function(method) {
        var options = $.extend( {
            'time': 0,
            'timings': {
                5: 'timer-warning'
            }
        }, method);
        el = this;
        switch (method) {
            case 'start':
                methods.start();
                break;
            case 'stop':
                methods.stop();
                break;
            case 'reset':
                methods.reset();
                break;
            default:
                methods.init(options);
        }
    };
})(jQuery);