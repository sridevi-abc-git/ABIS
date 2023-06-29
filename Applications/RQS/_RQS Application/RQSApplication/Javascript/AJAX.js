
var m_removeMessage;

$(document).ready(function ()
{

}); // $(document).ready()

function wcfPost(url, data)
{
    var info;

    info = JSON.stringify(data);

    $.ajax(
    {
        type: 'post',
        url: url,
        data: info,
        contentType: 'application/json; charset=utf-8',
        dataType: 'json',

        // this event is called prior to the service being called.
        beforeSend: beforeSend,

        // this event is first called when the service responds to the AJAX call.  This allows
        //  preprocessing of the response data
        dataFilter: dataFilter,
        
        success: success,
        error: error,
        complete: complete
    });

    return false;
} // wcfPost

function beforeSend(jqXHR, settings)
{
    m_removeMessage = true;
    return true;
}

function dataFilter(data, type)
{
    var msg = JSON.parse(data);

    // If the response has a ".d" top-level property,
    //  return what's below that instead.
    if (msg.hasOwnProperty('d'))
        return JSON.stringify(msg.d);
    else
        return data;
}

function success(response)
{
    var data = jQuery.parseJSON(response);
    if (typeof data === 'object') {
        $.each(data, function (key, value) {
            switch (key.toLowerCase()) {
                case "url":
                    window.location.assign(value);
                    break;

                case "err":
                	m_removeMessage = newMsg(value, true, g_messageBoxErrorButton);
                    break;

                case "msg":
                    m_removeMessage = newMsg(value, false, g_messageBoxButton);
                    break;

                case "data":
                    Process(value);
                    break;

                default:
                    Process(value);
                    break;
            }
        });
    }
}

function error(xhr, options, error)
{
    if (xhr.responseText == undefined)
    {
        newMsg({
            'Service': '[' + g_webService + ']',
            'Service Status:': xhr.status,
            'Service Error': xhr.statusText
        }, true, m_defaultButton);
    }
    else
    {
        if (xhr.responseText.length == 0) {
            newMsg({ 'URL': g_webService, 'Service Status:': xhr.status, 'Service Error': xhr.statusText }, true, m_defaultButton);
        }
        else {
            (typeof xhr.responseText == 'string') ? newMsg({ 'Service': g_webService, 'Message': xhr.responseText }, true, m_defaultButton) :
                                                    newMsg(eval('(' + xhr.responseText + ')'), true, m_defaultButton);
        }
    }

    m_removeMessage = false;
}

function complete(jqXHR, textStatus)
{
    if ($('#msg-target-data')[0].children.length > 0 && m_removeMessage)
    {
        _modal.close()
        _modal = undefined;
        $('div', '#msg-target-data').remove();
        $("body").css("cursor", "auto");
    }
}

function Process(response)
{
    return true;
}