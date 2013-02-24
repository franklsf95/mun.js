(function($) {
    var methods = {
        init: function(options) {
            return this.each( function() {
                var $this = $(this);
                var data = $this.data('timer');
                if (!data) {
                    data = $.extend({}, {
                        'time': 10,
                        'timings' : {
                            5: 'timer-warning'
                        }
                    }, options);
                } else {
                    data = $.extend({}, data, options);
                }
                data.now = data.time;
                $this.data('timer', data);
                render(data, $this);
            });
        },
        start: function() {
            return this.each( function() {
                var $this = $(this);
                var data = $this.data('timer');
                data.thread = setInterval(function() {
                    data.now--;
                    if (data.now === 0)
                        methods.stop();
                    render(data, $this);
                }, 1000);
                $this.data('timer', data);
            });
        },
        stop: function() {
            return this.each( function() {
                clearInterval( $(this).data('timer').thread );
            });
        },
        reset: function() {
            return this.each( function() {
                var $this = $(this);
                var data = $this.data('timer');
                clearInterval( data.thread );
                data.now = data.time;
                $this.data('timer', data);
                render();
            });
        }
    };
    var render = function(data, $el) {
        var _now = data.now;
        var hours = Math.floor(_now / 3600);
        _now %= 3600;
        var minutes = Math.floor(_now / 60);
        var seconds = _now % 60;
        var str = '';
        if (hours > 0) str += hours + ':';
        str += minutes + ':';
        if (seconds < 10) str += '0';
        str += seconds;
        $el.html(str);

        for (var t in data.timings) {
            if (data.now === t) {
                var cmd = data.timings[t];
                if (typeof cmd === 'string') {
                    $el.addClass(cmd);
                } else {
                    for (var prop in cmd) {
                        $el.css(prop, cmd[prop]);
                    }
                }
                break;
            }
        }
    };

    $.fn.timer = function() {
        var method = arguments[0];
        if ( methods[method] ) {
            return methods[ method ].apply( this );
        } else if ( typeof method === 'object' || ! method ) {
            return methods.init.apply( this, arguments );
        } else {
            $.error( 'Method ' + method + ' does not exist on jQuery.timer' );
        }
    };
})(jQuery);