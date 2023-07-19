
//  File:       ABC-Bargraph.js




function bargraph(canvas_name, title, footer, vertical)
{
    // private properties
    var m_this;
    var m_context;
    var m_width;
    var m_height;
    var m_offset;
    var m_x;
    var m_vertical;
    var m_maxBarWidth = 20;
    var m_title;
    var m_footer;

    // public properties
    this.background;


    var init = function (canvas_name, title, footer, vertical)
    {
        var canvas = document.getElementById(canvas_name);

        m_context = canvas.getContext("2d");
        m_context.clearRect(0, 0, canvas.width, canvas.height);

        m_this = this;

        m_this.background = "#FFFFFF";
        m_height = m_context.canvas.height - 10;
        m_width  = m_context.canvas.width  - 10;
        m_vertical = vertical || false;
        m_title = title;
        m_footer = footer;
        m_offset = (m_vertical) ? m_height * .7 : m_width - (m_width * .7);
        
    }

    init(canvas_name, title, footer, vertical);

    var draw = function (items)
    {
//        var inx;
        var margine = 4;
        var centerOffset;
        var bars;
        var max_count = 0;
        var ratio;
        var x = 0;
        var y = 0;
        var w;
        var h;
        var i = 0;

        // add header
        m_context.font = "bold 14pt sans-serif";
        m_context.fillStyle = "white";
        m_context.textAlign = 'center';
        m_context.fillText(m_title, m_width / 2, 20);
        m_context.fillText(m_footer, m_width / 2, m_height);
        m_context.font = "bold 10pt sans-serif";
        m_context.fillText('July 01, 2014', m_width / 2, 40);

        bars = Object.keys(items).length;
        
        if (m_vertical)
        {
            w = (m_width / bars) - margine;
            if (w > m_maxBarWidth) w = m_maxBarWidth;
            centerOffset = ((m_width / 2) - ((w + margine) * (bars / 2)));
        }
        else
        {
            h = (m_height / bars) - margine;
            if (h > m_maxBarWidth) h = m_maxBarWidth;
            centerOffset = ((m_height / 2) - ((h + margine) * (bars / 2)));
        }

        m_context.fillStyle = "#333";
        m_context.font = "bold 10pt sans-serif";

        // get max number
        for (key in items)
        {
            if (parseInt(max_count) < parseInt(items[key].TOTAL)) max_count = items[key].TOTAL;
        }

        for (key in items)
        {
            ratio = parseInt(items[key].TOTAL) / max_count;
            if (m_vertical)
            {
                h = (m_height / 2) * ratio * -1;
                x = (i * (w + margine)) + margine + centerOffset;
                y = m_offset;
            }
            else
            {
                w = (m_width / 2) * ratio;
                x = m_offset;
                y = (i * (h + margine)) + margine + centerOffset;
            }

            i++;

            create_bar(items[key], x, y, w, h, ratio);
        }


    }

    var create_bar = function (item, x, y, w, h, ratio)
    {
        var start = (m_vertical)?  (m_offset / m_height)      : (m_offset / m_width);
        var stop  = (m_vertical)? ((m_offset + h) / m_height) : ((m_offset + w) / m_width);
        var width = (m_vertical) ? 0 : m_width;
        var height = (m_vertical) ? m_height : 0;

        m_context.save();

        // build border
        m_context.fillStyle = "black";
        m_context.fillRect(x, y, w, h); // x, y, width, hight (xy upper left conner)

        grd = m_context.createLinearGradient(0, 0, width, height);
        grd.addColorStop(stop, item.COLOR);    // stop
        grd.addColorStop(start, "white");   // start

        m_context.fillStyle = grd;
        m_context.fillRect(x + 1, y - 1, w - 2, h + 2); // x, y, width, hight (xy upper left conner)

        m_context.fillStyle = "#fff";
        if (vertical)
        {
            m_context.textAlign = 'center';
            m_context.fillText(item.TOTAL, x + w / 2, y + h - 10);

            m_context.save();
            m_context.translate(x + 5, y + 15);
            m_context.rotate(-Math.PI / 2);

//            m_context.fillStyle = "#fff";
            m_context.textAlign = 'right';
            m_context.fillText(item.TEXT, 0, 10);
            m_context.restore();
        }
        else
        {
            m_context.fillText(item.TOTAL, x + w + 10, y + (h / 2) + 4);

//            m_context.fillStyle = "#fff";
            m_context.textAlign = 'right';
            m_context.fillText(item.TEXT, x - 10, y + h - 2);
        }


        m_context.restore();


    }


    // public properties and methods

    this.update = function (value)
    {
        draw(value);
    }

}