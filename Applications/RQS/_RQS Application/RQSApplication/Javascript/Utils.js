

var _modal;

function printdiv(id)
{
    var divToPrint = document.getElementById(id);
    newWin = window.open("",'_blank', 'toolbar=no,status=no,menubar=no,scrollbars=no,resizable=no,left=10000, top=10000, visible=none', '');
    newWin.document.write(divToPrint.outerHTML);
    newWin.document.close();
    newWin.print();
    newWin.close();
 
}

function printpreview(id)
{
	//var divToPrint = document.getElementById(id);

	newWin = window.open("", '', 'toolbar=no,status=no,menubar=no,scrollbars=yes,resizable=no,width=816,height=1056', '');
	newWin.document.write(m_infodata);
	newWin.document.close();
	newWin.focus();


}
$(document).ready(function ()
{
    $.support.boxModel = true;
    if ($("[id$='hdnUser']").val().length > 0)
    {
        g_user = JSON.parse(decode($("[id$='hdnUser']").val()));
        jQuery("[id$='username']")[0].innerText = g_user.USER_NAME;
    }
});


function newMsg(msg, error, btns) {
    if (_modal !== undefined && _modal !== null) {
        _modal.close();
        _modal.undefined;
    }
    // msg = msg['data'];

    $('div', '#msg-target-data').remove();
    $("body").css("cursor", "auto");

    return dsplMsg(msg, error, btns);
} // newMsg()

//**********************************************************************************
// Function:
//
// Description:
//
// Parameters:
//
// Returns:
//**********************************************************************************
function dsplMsg(msg, error, btns) {
    var color;

    error = (typeof error === 'undefined') ? true : error;
    color = (error) ? "#A3010D" : "#018307";

    if (_modal !== undefined && _modal !== null) _modal.close();

    msg_add(msg);

    if (btns !== null) msg_addbtn(btns);

    $('#msg-target').css({ "color": color })
    $('#msg-target').modal({
        opacity: 0,
        overlayCss: { backgroundColor: "#fff" },
        onShow: function () {
            _modal = this;
        }
    });

    return false;
} // dsplMsg

//**********************************************************************************
// Function:
//
// Description:
//
// Parameters:
//
// Returns:
//**********************************************************************************
function msg_addbtn(btns) {
    var btnArea;

    // set default ok button if no buttons are passed
    if (btns === undefined) btns = m_defaultButton;

    // remove any old buttons floating around
    jQuery('#message-buttons').remove();
    btnArea = jQuery('<div/>', { id: 'msg-buttons' }).appendTo('#msg-target-data');

    jQuery('<hr/>').appendTo(btnArea);
    jQuery('<div/>', { style: 'height:10px' }).appendTo(btnArea);

    // add new buttons from button array
    jQuery.each(btns, function (key, value) {
        jQuery("<input type='button' />").attr(value).appendTo(btnArea);
    });

    btnArea.show();
} // msg_addbtn

//**********************************************************************************
// Function:
//
// Description:
//
// Parameters:
//
// Returns:
//**********************************************************************************
function msg_add(msgItem) {
    var msgRoot;

    if (typeof msgItem === 'object') {
        msgRoot = $("<div class='msg-info' />");
        msgRoot.appendTo('#msg-target-data');

        msgRoot.css('text-align', 'left').css('white-space', 'nowrap').css('padding-right:10px');

        $.each(msgItem, function (key, value) {
            var msg = $('<div/>').css('margin-top', '10px');
            msg.appendTo(msgRoot);

            $('<div class=\'inline\ msg-label\' />').text(key + ':').appendTo(msg);
            $('<div class=\'inline\' />').html(value).appendTo(msg);
        });
    }
    else {
        if (msgItem.indexOf('</div>') > -1) {
            $('#msg-target-data').html(msgItem);
        }
        else {
            format_msg(msgItem, $('#msg-target-data'));
        }
    }

    return false;
} // msg_add()


function format_msg(text, root) {
    var lines;
    var row = jQuery(document.createElement('div'));
    var cell;

    lines = text.replace(/\r/g, '').split('\n');
    jQuery.each(lines, function () {
        // build display line
        cell = jQuery(document.createElement('div'));
        cell.html(this);
        cell.appendTo(root);
    });
}



//**********************************************************************************
// Function:
//
// Description:
//
// Parameters:
//
// Returns:
//**********************************************************************************
function isDirty(pageid, inputItem) {
    var isChanged = false;
    var info;
    var option;
    var reportId;

    if (pageid === null) pageid = $('form').attr('id');

    info = '<ROOT>';

    // get all input controls for selected section and check for any inputs have changed
    $('input[type != button], select, textarea', '#' + pageid).each(function ()
    {
		// make sure item has name
    	if (this.name.length == 0) return true;

        switch (this.type.toLowerCase()) {
            case 'text':
            case 'number':
            case 'password':
            case 'email':
            case 'textarea':
                if (this.value.length > 0) {
                    info += '<' + this.name.toUpperCase() + '>' + this.value + '</' + this.name.toUpperCase() + '>';
                }

                isChanged = (this.value === this.defaultValue ? isChanged : true);
                break;

            case 'hidden':
                if (this.className == 'return' && this.value.length > 0) {
                    info += '<' + this.name.toUpperCase() + '>' + this.value + '</' + this.name.toUpperCase() + '>';
                    isChanged = (this.value === this.defaultValue ? isChanged : true);
                }
                break;

            case 'radio':
                if ($(this).is(':checked')) {
                    info += '<' + this.name.toUpperCase() + '>' + $(this).val() + '</' + this.name.toUpperCase() + '>';
                }
                isChanged = (this.checked === this.defaultChecked ? isChanged : true);
                break;

            case 'checkbox':
                if ($(this).is(':checked')) {
                    info += '<' + this.name.toUpperCase() + '>' + ((this.checked) ? $(this).val() : '') + '</' + this.name.toUpperCase() + '>';
                }
                isChanged = (this.checked === this.defaultChecked ? isChanged : true);
                break;

            case 'select-one':
                if (this.value.length > 0)
                {
                	if (this.name.toLowerCase() == 'select_report_id')
                	{
                		option = this.options[this.value];
                		reportId = option.attributes['RPT_ID'];

                		info += '<REPORT_ID>' + reportId + '</REPORT_ID>';
						$(this).find('option').each(function ()
						{
							isChanged = (this.selected == this.defaultSelected ? isChanged : true);
						});
                	}
                	else
                	{
						info += '<' + this.name.toUpperCase() + '>' + this.value + '</' + this.name.toUpperCase() + '>';
						$(this).find('option').each(function ()
						{
							isChanged = (this.selected == this.defaultSelected ? isChanged : true);
						});
                	}
                }
                break;
        }
    });

    info += '</ROOT>';
    inputItem['data'] = info;

    return isChanged;

} // isDirty()

function getValues(pageid, inputItems)
{
	var isChanged	= false;
	var info		= {};
	var option;
	var reportId;
	var valid		= true;

	if (g_user != null)
	{
		for (name in g_user)
		{
			info[name] = g_user[name];
		}
	}

	if (pageid === null) pageid = $('form').attr('id');

	// get all input controls for selected section and check for any inputs have changed
	$('input[type != button], select, textarea', '#' + pageid).each(function ()
	{
		//valid &= jQuery('#').validation('val');

		// make sure item has name
		if (this.name.length == 0) return true;

		switch (this.type.toLowerCase())
		{
			case 'text':
			case 'number':
			case 'password':
			case 'email':
			case 'textarea':
				if (this.value.length > 0)
				{
					info[this.name.toUpperCase()] = this.value;
					//info += '<' + this.name.toUpperCase() + '>' + this.value + '</' + this.name.toUpperCase() + '>';
				}

				isChanged = (this.value === this.defaultValue ? isChanged : true);
				break;

			case 'hidden':
				if (this.className == 'return' && this.value.length > 0)
				{
					info[this.name.toUpperCase()] = this.value;
					//info += '<' + this.name.toUpperCase() + '>' + this.value + '</' + this.name.toUpperCase() + '>';
					isChanged = (this.value === this.defaultValue ? isChanged : true);
				}
				break;

			case 'radio':
				if ($(this).is(':checked'))
				{
					info[this.name.toUpperCase()] = this.value;
					//info += '<' + this.name.toUpperCase() + '>' + $(this).val() + '</' + this.name.toUpperCase() + '>';
				}
				isChanged = (this.checked === this.defaultChecked ? isChanged : true);
				break;

			case 'checkbox':
				if ($(this).is(':checked'))
				{
					info[this.name.toUpperCase()] = ((this.checked) ? $(this).val() : '');
					//info += '<' + this.name.toUpperCase() + '>' + ((this.checked) ? $(this).val() : '') + '</' + this.name.toUpperCase() + '>';
				}
				isChanged = (this.checked === this.defaultChecked ? isChanged : true);
				break;

			case 'select-one':
				if (this.value.length > 0)
				{
					//if (this.name.toLowerCase() == 'select_report_id')
					//{
					//	option = this.options[this.value];
					//	reportId = option.attributes['RPT_ID'];

					//	info += '<REPORT_ID>' + reportId + '</REPORT_ID>';
					//	$(this).find('option').each(function ()
					//	{
					//		isChanged = (this.selected == this.defaultSelected ? isChanged : true);
					//	});
					//}
					//else
					{
						info[this.name.toUpperCase()] = this.value;
						//info += '<' + this.name.toUpperCase() + '>' + this.value + '</' + this.name.toUpperCase() + '>';
						$(this).find('option').each(function ()
						{
							isChanged = (this.selected == this.defaultSelected ? isChanged : true);
						});
					}
				}
				break;
		}

		// validate input item
		//if ($(this).validation != undefined)
		//	valid &= $(this).validation('val');

	});

	//info += '</ROOT>';
	inputItems['data'] = JSON.stringify(info);

	return (valid && isChanged);

} // getValues()



//**********************************************************************************
// Function:
//
// Description:
//
// Parameters:
//
// Returns:
//**********************************************************************************
function updateFields(results) {
    var field;
    var type;

    $.each(results, function (key, value) {
        field = $('[name="' + key + '"]');
        if ((field.length > 0) && (value != null)) {
            type = field[0].tagName == 'INPUT' ? field.attr('type') : field[0].type;
            if (typeof type !== 'undefined') {
                switch (type.toLowerCase()) {
                    case 'radio':
                    case 'checkbox':
                        $("[name='" + key + "'][value='" + value + "']").prop('checked', true);
                        break;

                    default:
                        field.val(value);
                        break;
                }
            }
            else {
                if (field[0].tagName == 'LABEL') field.text(value);
            }
        }
    });

    accept(null);
} // updateFields()

//**********************************************************************************
// Function:
//
// Description:
//
// Parameters:
//
// Returns:
//**********************************************************************************
function accept(pageid) {
    if (pageid === null) pageid = $('form').attr('id');

    // get all input controls for selected section and check for any inputs have changed
    $('input[type != button], select', '#' + pageid).each(function () {
        // clear any fields with error displayed
        var err_ctrl = $(this).data('err');
        if (err_ctrl !== undefined) {
            $('#' + err_ctrl).text('unknown').hide();
            $(this).css({ 'color': '', 'background-color': '' });
        }

        switch (this.type.toLowerCase()) {
            case 'text':
            case 'hidden':
            case 'number':
            case 'password':
                this.defaultValue = this.value;
                break;

            case 'radio':
            case 'checkbox':
                this.defaultChecked = this.checked;
                break;

            case 'select-one':
                $(this).find('option').each(function () {
                    this.defaultSelected = this.selected
                });
                break;
        }
    });

}  // accept()

function getDateTime()
{
    var now = new Date();
    var d = now.getDate();
    var m = now.getMonth() + 1;
    var y = now.getFullYear();
    var h = now.getHours();
    var mi = now.getMinutes();

    d = d < 10 ? '0' + d : d;
    m = m < 10 ? '0' + m : m;
    h = h < 10 ? '0' + h : h;
    mi = mi < 10 ? '0' + mi : mi;
    return m + '/' + d + '/' + y + ' ' + h + ':' + mi;
}

function getDateDaysBack(daysBack)
{
	var now = new Date();
		now.setDate(now.getDate() - daysBack);

	var d = now.getDate();
	var m = now.getMonth() + 1;
	var y = now.getFullYear();

	d = d < 10 ? '0' + d : d;
	m = m < 10 ? '0' + m : m;
	return m + '/' + d + '/' + y;
}


function getDate()
{
    var now = new Date();
    var d = now.getDate();
    var m = now.getMonth() + 1;
    var y = now.getFullYear();

    d = d < 10 ? '0' + d : d;
    m = m < 10 ? '0' + m : m;
    return m + '/' + d + '/' + y;
}

function getTime()
{
    var now = new Date();
    var h = now.getHours();
    var mi = now.getMinutes();

    h = h < 10 ? '0' + h : h;
    mi = mi < 10 ? '0' + mi : mi;
    return h + ':' + mi;
}

//function initReportSelection(data, schedule) {
//    var recs = jQuery.parseJSON(data.REPORTS);
//    var select = document.getElementById('ddlReports');
//    var option;
//    var outParams;

//    if (select == undefined) return true;

//    jQuery(select).empty();
//    option = document.createElement("option");
//    option.text = 'Select Report ...';
//    option.value = '';
//    select.appendChild(option);

//    for (var inx = 0; inx < recs.length; inx++)
//    {
//		// check if read only and called from schedule screen
//    	if ((recs[inx].ACCESS_TYPE_IND != 'E') && schedule) continue;
//        g_reportRecords[recs[inx].RPT_ID] = recs[inx];

//        option = document.createElement("option");
//        option.text = recs[inx].RPT_DESC;
//        option.value = inx + 1;

//        option.attributes['SERVICE'] = recs[inx].SERVICE;
//		option.attributes['RPT_ID'] = recs[inx].RPT_ID;
//		option.attributes['INPUT_PARAMETER'] = recs[inx].INPUT_PARAMETER;

//		select.appendChild(option);

//    }

//    return recs.length;
//}


//function initOfficSelection(data)
//{
//    var recs;
//    var select = document.getElementById('selected_office');
//    var option;
//    var outParams;

//    if (select == undefined) return true;

//    recs = jQuery.parseJSON(data.OFFICELIST);

//    jQuery(select).empty();
//    option = document.createElement("option");
//    option.text = 'Select Office ...';
//    option.value = '';
//    select.appendChild(option);

//    for (var inx = 0; inx < recs.length; inx++)
//    {
//        //g_reportRecords[recs[inx].RPT_ID] = recs[inx];
//        //g_outputRecords[recs[inx].RPT_ID] = jQuery.parseJSON(recs[inx].OUTPUT_PARAMETER);
//        g_officeRecords[recs[inx].OFFICEID] = recs[inx];

//        option = document.createElement("option");
//        option.text = recs[inx].OFFICECODE + ' - ' + recs[inx].OFFICENAME;
//        option.value = recs[inx].OFFICEID;

//        if (jQuery("[id$='office_id']").val() == recs[inx].OFFICEID)
//        {
//            option.selected = true;
//        }
        
//        select.appendChild(option);
//    }

//    (recs.length > 1) ? jQuery('#office-div').show() : jQuery('#office-div').hide();

//    return recs.length;
//}

function initReportSelection(data)
{
	var recs = data.REPORTS;
	var select = jQuery("[name='report_number']", '#input-area');
	var option;
	var outParams;

	jQuery(select).empty();		// clear any items in drop down box

	// create first option to be displayed
	option = document.createElement("option");
	option.text = 'Select Report ...';
	option.value = '';
	select[0].appendChild(option);

	for (var inx = 0; inx < recs.length; inx++)
	{
		// create option for each record
		option = document.createElement("option");
		option.text = recs[inx].REPORT_NAME;
		option.value = recs[inx].REPORT_NUMBER;

		if (recs.length == 1)
		{
			// select report as selected report
			option.selected = true;

			// hide drop down
			select.parent().parent().hide();
		}

		select[0].appendChild(option);

	}

	return recs.length;
}


function initOfficSelection(data)
{
	var recs = data.OFFICE.OFFICE_LIST;
	var select = jQuery("[name='officeobjectid']", '#input-area');
	var option;
	var name;

	jQuery(select).empty();

	// create first opting to be displayed
	option = document.createElement("option");
	option.text = 'Select Office ...';
	option.value = '';
	select[0].appendChild(option);

	for (var inx = 0; inx < recs.length; inx++)
	{
		option = document.createElement("option");
		option.text = recs[inx].OFFICENAME;
		option.value = recs[inx].OFFICEOBJECTID;

		if (recs.length == 1)
		{
			// select report as selected report
			option.selected = true;

			// hide drop down
			select.parent().parent().hide();
		}

		select[0].appendChild(option);
	}


	//	(recs.length > 1) ? jQuery('#office-div').show() : jQuery('#office-div').hide();

	return;
}



function getOutParameter(rpt_id, parameter, rpt_type)
{
    var outputs = {};
    var values = {};

    //jQuery.parseJSON("{"16":"{"EXCEL":"{"default_flg":"Y","name":"SUSPENSIONS_1A","format":"E","file":"SUSPENSIONS","heading":"Suspension (Part 1)","service":"RQS;Reports.Report"}"}"}")
    //jQuery.parseJSON("{\"EXCEL\":\"RQS;Reports.Report\"}")
    //jQuery.parseJSON("{\"16\":{\"EXCEL\":{\"a\":\"RQS;Reports.Report\"}}}")

    //outputs = jQuery.parseJSON(g_reportRecords[rpt_id].OUTPUT_PARAMETER)
    if (g_outputRecords[rpt_id] != null)
    {
        values = (g_outputRecords[rpt_id][rpt_id][rpt_type] != null) ? g_outputRecords[rpt_id][rpt_id][rpt_type.toUpperCase()] : null;
    }

    return (values != null) ? values[parameter.toUpperCase()] : null;

}

function DisplayHTML(data)
{
    var wnd = window.open('', '', 'scrollbars=yes,resizable=yes');
	wnd.document.open();
	wnd.document.write(data);
	wnd.document.close();
	wnd.focus();
}

function DisplayPDF(data)
{
	window.open(data);
	//window.open("data:application/pdf;base64, " + escape(data));

	//newWin = window.open("", '', 'toolbar=no,status=no,menubar=no,scrollbars=yes,resizable=yes,width=816,height=500', '');
	//newWin.document.open();
	//newWin.document.write(data);
	//newWin.document.close();
	//newWin.focus();

	//PDFViewerApplication.open()

}
function DisplayExcel(data) {
    var url = data;
    window.open(url);
}

//function DisplayExcelData(data)
//{
//    var mtype = 'application/excel'; //'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';//'application/vnd.ms-excel';
//    var url = 'data:' + mtype + ';base64,' + data; // base64data;

//    window.open(url);
//}

function CreateReportElement(column, value, row) {
    var cell;

    cell = jQuery(document.createElement('div'));
    cell.html(value);
    cell.attr('id', column.toLowerCase());
    cell.attr('class', column.toLowerCase());
    cell.appendTo(row);

    return cell;
}

function zeroPad(num, places) {
    var zero = places - num.toString().length + 1;
    return Array(+(zero > 0 && zero)).join("0") + num;
}



var b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

function encode(data) {
    var o1;
    var o2;
    var o3;
    var h1;
    var h2;
    var h3;
    var h4;
    var bits;
    var i = 0;
    var ac = 0;
    var enc = '';
    var tmp_arr = [];

    if (!data) {
        return data;
    }

    do { // pack three octets into four hexets
        o1 = data.charCodeAt(i++);
        o2 = data.charCodeAt(i++);
        o3 = data.charCodeAt(i++);

        bits = o1 << 16 | o2 << 8 | o3;

        h1 = bits >> 18 & 0x3f;
        h2 = bits >> 12 & 0x3f;
        h3 = bits >> 6 & 0x3f;
        h4 = bits & 0x3f;

        // use hexets to index into b64, and append result to encoded string
        tmp_arr[ac++] = b64.charAt(h1) + b64.charAt(h2) + b64.charAt(h3) + b64.charAt(h4);
    } while (i < data.length);

    enc = tmp_arr.join('');

    var r = data.length % 3;

    return (r ? enc.slice(0, r - 3) : enc) + '==='.slice(r || 3);
}


function decode(data) {
    var o1;
    var o2;
    var o3;
    var h1;
    var h2;
    var h3;
    var h4;
    var bits;
    var i = 0;
    var ac = 0;
    var dec = '';
    var tmp_arr = [];

    if (!data) {
        return data;
    }

    data += '';

    do { // unpack four hexets into three octets using index points in b64
        h1 = b64.indexOf(data.charAt(i++));
        h2 = b64.indexOf(data.charAt(i++));
        h3 = b64.indexOf(data.charAt(i++));
        h4 = b64.indexOf(data.charAt(i++));

        bits = h1 << 18 | h2 << 12 | h3 << 6 | h4;

        o1 = bits >> 16 & 0xff;
        o2 = bits >> 8 & 0xff;
        o3 = bits & 0xff;

        if (h3 == 64) {
            tmp_arr[ac++] = String.fromCharCode(o1);
        } else if (h4 == 64) {
            tmp_arr[ac++] = String.fromCharCode(o1, o2);
        } else {
            tmp_arr[ac++] = String.fromCharCode(o1, o2, o3);
        }
    } while (i < data.length);

    dec = tmp_arr.join('');

    return dec.replace(/\0+$/, '');
}



function DisplayReportFilter(show)
{
    if (show)
    {
        DisplayReportList(false);
        DisplayReportArea(false);

        DisplayNavigation(true);
        jQuery('#select-div').show();
    }
    else
    {
        jQuery('#select-div').hide();
    }
}

function DisplayReportList(show)
{
    if (show)
    {
        DisplayReportFilter(false);
        DisplayReportArea(false);
        DisplayNavigation(false);

        jQuery('#report-list-div').show()
    }
    else
    {
        jQuery('#report-list-div').hide();
    }
}

function DisplayReportArea(show)
{
    if (show)
    {
        DisplayReportFilter(false);
        DisplayReportList(false);
        DisplayNavigation(false);

        jQuery('#report-div').show();

        // call setup export buttons
    }
    else
    {
        jQuery('#report-div').hide();
    }
}


function CreateElement(element, value, parent)
{
	var cell;

	cell = jQuery(document.createElement(element));
	cell.html(value);
	cell.appendTo(parent);

	return cell;
}


//************************************************************************************

//************************************************************************************
var VAL_DATEPATTERNSTANDARD = '^(((0?[1-9]|1[012])/(0?[1-9]|1\\d|2[0-8])|(0?[13456789]|1[012])/(29|30)|'
                        + '(0?[13578]|1[02])/31)/(19|[2-9]\\d)\\d{2}|0?2/29/((19|[2-9]\\d)'
                        + '(0[48]|[2468][048]|[13579][26])| '
                        + '(([2468][048]|[3579][26])00)))$';
var VAL_TIME24 = '^([01][0-9]|2[0-3]):[0-5][0-9]$'
var VAL_YEAR = '^(19|20)[0-9][0-9]$';
var VAL_EMAIL = // email
    '^[a-zA-Z][\\w\\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\\w\\.-]*[a-zA-Z0-9]\\.[a-zA-Z][a-zA-Z\\.]*[a-zA-Z]$';
var VAL_EMAIL_SHORT = '^(([a-zA-Z][\\w\\.-]*[a-zA-Z0-9];?)(;[ ]*?[a-zA-Z][\\w\\.-]*[a-zA-Z0-9])*)$';

(function ($)
{
    var lastid = "";
    var def_options = { key_filter: null, validator: null, required: false, err: null, method: 'validate' };

    var methods =
    {
        add: function (options)
        {
            var err_ctrl;
            var parent;

            $(this).data($.extend({}, def_options, options));

            // if no error id create id and add after element
            err_ctrl = $(this).data('err');
            if (err_ctrl === null)
            {
                err_ctrl = this[0].id + '_err';
                parent = this[0].parentElement;
                $(parent).append('<div id=' + err_ctrl + '></div>');
                $('#' + err_ctrl).hide();
                $(this).data('err', err_ctrl);
            }

            // validate input when focus is lost
            this.bind('focusout', function () { arguments[0].data = false; methods[$(this).data('method')].apply($(this), arguments); });
        },

        val: function ()
        {
            var valid = true;

            if (methods[$(this).data('method')] != null)
            {
                valid = methods[$(this).data('method')].apply($(this), arguments);
            }
            return valid;
        },

        validate: function (override)
        {
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
            if (override !== undefined)
            {
                req = (override instanceof Object) ? override.data : override;
            }

            switch (this[0].type)
            {
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
                    $(this).find('option').each(function ()
                    {
                        isChanged = (this.selected == this.defaultSelected ? isChanged : true);
                    });
                    break;

                default:
                    isChanged = (this[0].value === this[0].defaultValue ? false : true);
                    value = this.val();
                    break;
            }

            if (req || (value.length > 0))
            {
                valid = (regx !== null) ? new RegExp(regx).test($(this).val()) : (value.length > 0);
                if (valid)
                {
                    // hide error message when valid
                    $('#' + err_ctrl).text('unknown').hide();
                    $(this).css({ 'color': '', 'background-color': '' });
                }
                else
                {
                    var msg = options['message'];
                    msg = (msg === undefined) ? ((value.length > 0) ? 'Invalid Entry' : 'Required')
                                                : (msg[(value.length > 0) ? 'INVALID' : 'REQUIRED']);

                    $('#' + err_ctrl).text(msg).css('color', 'red').show();
                    $(this).css({ 'color': 'red', 'background-color': '#ffD0D0' });
                }
            }
            else
            {
                if (isChanged)
                {
                    valid = true;
                    $('#' + err_ctrl).text('unknown').hide();
                    $(this).css({ 'color': '', 'background-color': '' });
                }
            }

            return valid;
        },

        DateTime: function (override)
        {
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
            if (override !== undefined)
            {
                req = (override instanceof Object) ? override.data : override;
            }

            msgs = options['message'];
            value = this.val();
            isChanged = (this[0].value === this[0].defaultValue ? false : true);

            if (req || (value.length > 0))
            {
                value = value.split(' ');
                if (value.length > 0)
                {
                    if (!datePat.test(value[0]))
                    {
                        msg = (msgs['INVALID_DATE'] === undefined) ? 'Invalid date entered' : msgs['INVALID_DATE'];
                        valid = false;
                    }

                    if (!timePat.test(value[1]))
                    {
                        msg = msg == null ?
                            (msgs['INVALID_TIME'] === undefined) ? 'Invalid time entered' : msgs['INVALID_TIME'] :
                            (msgs['INVALID_DATETIME'] === undefined) ? 'Invalid date and time entered' : msgs['INVALID_DATETIME'];
                        valid = false;
                    }
                }
                else
                {
                    msg = (msgs['REQUIRED'] === undefined) ? 'Please enter valid date and time.' : msgs['REQUIRED'];
                    valid = false;
                }

                if (valid)
                {
                    // hide error message when valid
                    $('#' + err_ctrl).text('unknown').hide();
                    $(this).css({ 'color': '', 'background-color': '' });
                }
                else
                {
                    msg = (msgs[msg] === undefined) ? ((value.length > 0) ? 'Invalid Entry' : 'Required')
                                                : (msgs[(value.length > 0) ? msg : 'REQUIRED']);

                    $('#' + err_ctrl).text(msg).css('color', 'red').show();
                    $(this).css({ 'color': 'red', 'background-color': '#ffD0D0' });
                }
            }
            else
            {
                if (isChanged)
                {
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
        validation: function (method)
        {
            if (methods[method])
            {
                return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
            }
            else if (typeof method === 'object' || !method)
            {
                return methods.init.apply(this, arguments);
            }
            else
            {
                $.error('Method ' + method + ' does not exist on jQuery.Verify');
            }
        }

    });


})(jQuery, window, document);


