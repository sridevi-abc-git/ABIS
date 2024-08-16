var VAL_DATEPATTERNSTANDARD = '^(((0?[1-9]|1[012])/(0?[1-9]|1\\d|2[0-8])|(0?[13456789]|1[012])/(29|30)|'
                        + '(0?[13578]|1[02])/31)/(19|[2-9]\\d)\\d{2}|0?2/29/((19|[2-9]\\d)'
                        + '(0[48]|[2468][048]|[13579][26])| '
                        + '(([2468][048]|[3579][26])00)))$';
var VAL_TIME24 = '^([01][0-9]|2[0-3]):[0-5][0-9]$'
var VAL_YEAR = '^(19|20)[0-9][0-9]$';
var VAL_EMAIL = // email
    '^[^@]*@[a-zA-Z0-9][\\w\\.-]*[a-zA-Z0-9]\\.[a-zA-Z][a-zA-Z\\.]*[a-zA-Z]$';
var VAL_EMAIL_SHORT = '^(([a-zA-Z0-9][\\w\\.-]*[a-zA-Z0-9];?)(;[ ]*?[a-zA-Z0-9][\\w\\.-]*[a-zA-Z0-9])*)$';
var VAL_NUMBER = '^[0-9]{0,}$';
var VAL_PHONE = '^[0-9]{10}$';

(function ($) {
    var lastid = "";
    var def_options = { key_filter: null, validator: null, required: false, err: null, method: 'validate' };

    var methods =
    {
        add: function (options) {
            var err_ctrl;
            var parent;

            $(this).data($.extend({}, def_options, options));

            // if no error id create id and add after element
            err_ctrl = $(this).data('err');
            if (err_ctrl === null) {
                err_ctrl = this[0].id + '_err';
                parent = this[0].parentElement;
                $(parent).append('<div id=' + err_ctrl + '></div>');
                $('#' + err_ctrl).hide();
                $(this).data('err', err_ctrl);
            }

            // validate input when focus is lost
            this.bind('focusout', function () { arguments[0].data = false; methods[$(this).data('method')].apply($(this), arguments); });
        },

        val: function () {
            return methods[$(this).data('method')].apply($(this), arguments);
        },

        validate: function (override) {
            var options = this.data();
            var regx = options['validator'];
            var req = options['required'];
            var err_ctrl = options['err'];
            var item;
            var value;
            var valid;
            var isChanged = false;

            // check last id to see if same id is called again (radio button list will have same names in list)
            if (lastid === this[0].name) return true;

            // check if control has been initialized with options
            if (options.required === undefined) return true;

            // check to see if required is overriden
            if (override !== undefined) {
                req = (override instanceof Object) ? override.data : override;
            }

            switch (this[0].type) {
                case 'text':
                case 'number':
                case 'password':
                case 'email':
                case 'textarea':
                    value = this.val();
                    isChanged = (this[0].value === this[0].defaultValue ? false : true);
                    break;

                    // check if radio button list
                case 'radio':
                    lastid = this[0].name;
                    item = $('[name="' + this[0].name + '"]:checked')
                    value = (item.length > 0) ? item.val() : '';
                    isChanged = (item.checked === item.defaultChecked ? false : true);
                    break;

                case 'checkbox':
                    value = this.val();
                    isChanged = (this[0].checked === this[0].defaultChecked ? false : true);
                    break;

                case 'select-one':
                    value = this.val();
                    $(this).find('option').each(function () {
                        isChanged = (this[0].selected == this[0].defaultSelected ? isChanged : true);
                    });
                    break;

                default:
                    isChanged = (this[0].value === this[0].defaultValue ? false : true);
                    value = this.val();
                    break;
            }

            if (req || (value.length > 0)) {
                valid = (regx !== null) ? new RegExp(regx).test($(this).val()) : (value.length > 0);
                if (valid) {
                    // hide error message when valid
                    $('#' + err_ctrl).text('unknown').hide();
                    $(this).css({ 'color': '', 'background-color': '' });
                }
                else {
                    var msg = options['message'];
                    msg = (msg === undefined) ? ((value.length > 0) ? 'Invalid Entry' : 'Required')
                                                : (msg[(value.length > 0) ? 'INVALID' : 'REQUIRED']);

                    $('#' + err_ctrl).text(msg).css('color', 'red').show();
                    $(this).css({ 'color': 'red', 'background-color': '#ffD0D0' });
                }
            }
            else {
                valid = true;
                $('#' + err_ctrl).text('unknown').hide();
                $(this).css({ 'color': '', 'background-color': '' });
            }

            return valid;
        },

        DateTime: function (override) {
            var options = this.data();
            var datePat = new RegExp(VAL_DATEPATTERNSTANDARD);
            var timePat = new RegExp(VAL_TIME24);
            var req = options['required'];
            var err_ctrl = options['err'];
            var item;
            var value;
            var valid = true;
            var isChanged = false;
            var msgs;
            var msg = null;

            // check if control has been initialized with options
            if (options.required === undefined) return true;

            // check to see if required is overriden
            if (override !== undefined) {
                req = (override instanceof Object) ? override.data : override;
            }

            msgs = options['message'];
            value = this.val();
            isChanged = (this[0].value === this[0].defaultValue ? false : true);

            if (req || (value.length > 0)) {
                value = value.split(' ');
                if (value.length > 0) {
                    if (!datePat.test(value[0])) {
                        msg = (msgs['INVALID_DATE'] === undefined) ? 'Invalid date entered' : msgs['INVALID_DATE'];
                        valid = false;
                    }

                    if (!timePat.test(value[1])) {
                        msg = msg == null ?
                            (msgs['INVALID_TIME'] === undefined) ? 'Invalid time entered' : msgs['INVALID_TIME'] :
                            (msgs['INVALID_DATETIME'] === undefined) ? 'Invalid date and time entered' : msgs['INVALID_DATETIME'];
                        valid = false;
                    }
                }
                else {
                    msg = (msgs['REQUIRED'] === undefined) ? 'Please enter valid date and time.' : msgs['REQUIRED'];
                    valid = false;
                }

                if (valid) {
                    // hide error message when valid
                    $('#' + err_ctrl).text('unknown').hide();
                    $(this).css({ 'color': '', 'background-color': '' });
                }
                else {
                    msg = (msgs[msg] === undefined) ? ((value.length > 0) ? 'Invalid Entry' : 'Required')
                                                : (msgs[(value.length > 0) ? msg : 'REQUIRED']);

                    $('#' + err_ctrl).text(msg).css('color', 'red').show();
                    $(this).css({ 'color': 'red', 'background-color': '#ffD0D0' });
                }
            }
            else {
                if (isChanged) {
                    valid = true;
                    $('#' + err_ctrl).text('unknown').hide();
                    $(this).css({ 'color': '', 'background-color': '' });
                }
            }

            return valid;
        }
    }


    $.fn.extend(
    {
        validation: function (method) {
            if (methods[method]) {
                return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
            }
            else if (typeof method === 'object' || !method) {
                return methods.init.apply(this, arguments);
            }
            else {
                $.error('Method ' + method + ' does not exist on jQuery.Verify');
            }
        }

    });


})(jQuery, window, document);


