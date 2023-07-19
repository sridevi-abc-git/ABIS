
var colours = [{ hex: "CD4A4A", rgb: "205,74,74" },
                    { hex: "CC6666", rgb: "204,102,102" },
                    { hex: "BC5D58", rgb: "188,93,88" },
                    { hex: "FF5349", rgb: "255,83,73" },
                    { hex: "FD5E53", rgb: "253,94,83" },
                    { hex: "FD7C6E", rgb: "253,124,110" },
                    { hex: "FDBCB4", rgb: "253,188,180" },
                    { hex: "FF6E4A", rgb: "255,110,74" },
                    { hex: "FFA089", rgb: "255,160,137" },
                    { hex: "EA7E5D", rgb: "234,126,93" },
                    { hex: "B4674D", rgb: "180,103,77" },
                    { hex: "A5694F", rgb: "165,105,79" },
                    { hex: "FF7538", rgb: "255,117,56" },
                    { hex: "FF7F49", rgb: "255,127,73" },
                    { hex: "DD9475", rgb: "221,148,117" },
                    { hex: "FF8243", rgb: "255,130,67" },
                    { hex: "FFA474", rgb: "255,164,116" },
                    { hex: "9F8170", rgb: "159,129,112" },
                    { hex: "CD9575", rgb: "205,149,117" },
                    { hex: "EFCDB8", rgb: "239,205,184" },
                    { hex: "D68A59", rgb: "214,138,89" },
                    { hex: "DEAA88", rgb: "222,170,136" },
                    { hex: "FAA76C", rgb: "250,167,108" },
                    { hex: "FFCFAB", rgb: "255,207,171" },
                    { hex: "FFBD88", rgb: "255,189,136" },
                    { hex: "FDD9B5", rgb: "253,217,181" },
                    { hex: "FFA343", rgb: "255,163,67" },
                    { hex: "EFDBC5", rgb: "239,219,197" },
                    { hex: "FFB653", rgb: "255,182,83" },
                    { hex: "E7C697", rgb: "231,198,151" },
                    { hex: "8A795D", rgb: "138,121,93" },
                    { hex: "FAE7B5", rgb: "250,231,181" },
                    { hex: "FFCF48", rgb: "255,207,72" },
                    { hex: "FCD975", rgb: "252,217,117" },
                    { hex: "FDDB6D", rgb: "253,219,109" },
                    { hex: "FCE883", rgb: "252,232,131" },
                    { hex: "F0E891", rgb: "240,232,145" },
                    { hex: "ECEABE", rgb: "236,234,190" },
                    { hex: "BAB86C", rgb: "186,184,108" },
                    { hex: "FDFC74", rgb: "253,252,116" },
                    { hex: "FFFF99", rgb: "255,255,153" },
                    { hex: "C5E384", rgb: "197,227,132" },
                    { hex: "B2EC5D", rgb: "178,236,93" },
                    { hex: "87A96B", rgb: "135,169,107" },
                    { hex: "A8E4A0", rgb: "168,228,160" },
                    { hex: "1DF914", rgb: "29,249,20" },
                    { hex: "76FF7A", rgb: "118,255,122" },
                    { hex: "71BC78", rgb: "113,188,120" },
                    { hex: "6DAE81", rgb: "109,174,129" },
                    { hex: "9FE2BF", rgb: "159,226,191" },
                    { hex: "1CAC78", rgb: "28,172,120" },
                    { hex: "30BA8F", rgb: "48,186,143" },
                    { hex: "45CEA2", rgb: "69,206,162" },
                    { hex: "3BB08F", rgb: "59,176,143" },
                    { hex: "1CD3A2", rgb: "28,211,162" },
                    { hex: "17806D", rgb: "23,128,109" },
                    { hex: "158078", rgb: "21,128,120" },
                    { hex: "1FCECB", rgb: "31,206,203" },
                    { hex: "78DBE2", rgb: "120,219,226" },
                    { hex: "77DDE7", rgb: "119,221,231" },
                    { hex: "80DAEB", rgb: "128,218,235" },
                    { hex: "199EBD", rgb: "251,58,189" },
                    { hex: "1CA9C9", rgb: "28,169,201" },
                    { hex: "1DACD6", rgb: "291,72,214" },
                    { hex: "9ACEEB", rgb: "154,206,235" },
                    { hex: "1A4876", rgb: "26,72,118" },
                    { hex: "1974D2", rgb: "25,116,210" },
                    { hex: "2B6CC4", rgb: "43,108,196" },
                    { hex: "1F75FE", rgb: "31,117,254" },
                    { hex: "C5D0E6", rgb: "197,208,230" },
                    { hex: "B0B7C6", rgb: "176,183,198" },
                    { hex: "5D76CB", rgb: "93,118,203" },
                    { hex: "A2ADD0", rgb: "162,173,208" },
                    { hex: "979AAA", rgb: "151,154,170" },
                    { hex: "ADADD6", rgb: "173,173,214" },
                    { hex: "7366BD", rgb: "115,102,189" },
                    { hex: "7442C8", rgb: "116,66,200" },
                    { hex: "7851A9", rgb: "120,81,169" },
                    { hex: "9D81BA", rgb: "157,129,186" },
                    { hex: "926EAE", rgb: "146,110,174" },
                    { hex: "CDA4DE", rgb: "205,164,222" },
                    { hex: "8F509D", rgb: "143,80,157" },
                    { hex: "C364C5", rgb: "195,100,197" },
                    { hex: "FB7EFD", rgb: "251,126,253" },
                    { hex: "FC74FD", rgb: "252,116,253" },
                    { hex: "8E4585", rgb: "142,69,133" },
                    { hex: "FF1DCE", rgb: "255,29,206" },
                    { hex: "FF48D0", rgb: "255,72,208" },
                    { hex: "E6A8D7", rgb: "230,168,215" },
                    { hex: "C0448F", rgb: "192,68,143" },
                    { hex: "6E5160", rgb: "110,81,96" },
                    { hex: "DD4492", rgb: "221,68,146" },
                    { hex: "FF43A4", rgb: "255,67,164" },
                    { hex: "F664AF", rgb: "246,100,175" },
                    { hex: "FCB4D5", rgb: "252,180,213" },
                    { hex: "FFBCD9", rgb: "255,188,217" },
                    { hex: "F75394", rgb: "247,83,148" },
                    { hex: "FFAACC", rgb: "255,170,204" },
                    { hex: "E3256B", rgb: "227,37,107" },
                    { hex: "FDD7E4", rgb: "253,215,228" },
                    { hex: "CA3767", rgb: "202,55,103" },
                    { hex: "DE5D83", rgb: "222,93,131" },
                    { hex: "FC89AC", rgb: "252,137,172" },
                    { hex: "F780A1", rgb: "247,128,161" },
                    { hex: "C8385A", rgb: "200,56,90" },
                    { hex: "EE204D", rgb: "238,32,77" },
                    { hex: "FF496C", rgb: "255,73,108" },
                    { hex: "EF98AA", rgb: "239,152,170" },
                    { hex: "FC6C85", rgb: "252,108,133" },
                    { hex: "FC2847", rgb: "252,40,71" },
                    { hex: "FF9BAA", rgb: "255,155,170" },
                    { hex: "CB4154", rgb: "203,65,84" },
                    { hex: "FFFFFF", rgb: "255,255,255" },
                    { hex: "EDEDED", rgb: "237,237,237" },
                    { hex: "DBD7D2", rgb: "219,215,210" },
                    { hex: "CDC5C2", rgb: "205,197,194" },
                    { hex: "95918C", rgb: "149,145,140" },
                    { hex: "414A4C", rgb: "65,74,76" },
                    { hex: "232323", rgb: "35,35,35" },
                    { hex: "000000", rgb: "0,0,0" }];


var data = [[30, "05 - VAN NUYS", "#440000"],
            [45, "06 - BAKERSFIELD", "#406080"],
            [50, "07 - RIVERSIDE", "#004400"],
            [70, "08 - PALM DESERT", "#203060"],
            [100, "22 - OAKLAND", "#800000"],
            [125, "23 - SACRAMENTO", "#000080"],
            [140, "28 - EUREKA", "#008000"],
            [150, "31 - REDDING", "#404040"]];

var data2 = {
    "02-MONROVIA": { "ABC220": "40", "ABC61": "19", "TOTAL": "59" },
    "03-LB/LAKEWOOD": { "ABC220": "34", "ABC61": "22", "TOTAL": "56" },
    "04-LA/METRO": { "ABC220": "49", "ABC61": "1", "TOTAL": "50" },
    "05-VAN NUYS": { "ABC220": "36", "ABC61": "27", "TOTAL": "63" },
    "06-BAKERSFIELD": { "ABC220": "24", "ABC61": "25", "TOTAL": "49" },
    "07-RIVERSIDE": { "ABC220": "51", "ABC61": "45", "TOTAL": "96" },
    "08-PALM DESERT": { "ABC220": "20", "ABC61": "7", "TOTAL": "27" },
    "09-SAN MARCOS": { "ABC220": "21", "ABC61": "13", "TOTAL": "34" },
    "10-SAN DIEGO": { "ABC220": "20", "ABC61": "16", "TOTAL": "36" },
    "11-SANTA ANA": { "ABC220": "45", "ABC61": "15", "TOTAL": "60" },
    "12-VENTURA": { "ABC220": "30", "ABC61": "10", "TOTAL": "40" },
    "13-SAN LUIS OBISPO": { "ABC220": "23", "ABC61": "11", "TOTAL": "34" },
    "18-CERRITOS ENFORCEMENT OFFICE  (CEO)": { "ABC220": "0", "ABC61": "38", "TOTAL": "38" },
    "21-FRESNO": { "ABC220": "36", "ABC61": "26", "TOTAL": "62" },
    "22-OAKLAND": { "ABC220": "42", "ABC61": "19", "TOTAL": "61" },
    "23-SACRAMENTO": { "ABC220": "63", "ABC61": "29", "TOTAL": "92" },
    "24-SAN FRANCISCO": { "ABC220": "100", "ABC61": "21", "TOTAL": "121" },
    "25-SAN JOSE": { "ABC220": "38", "ABC61": "7", "TOTAL": "45" },
    "26-SALINAS": { "ABC220": "27", "ABC61": "6", "TOTAL": "33" },
    "27-SANTA ROSA": { "ABC220": "94", "ABC61": "10", "TOTAL": "104" },
    "28-EUREKA": { "ABC220": "0", "ABC61": "2", "TOTAL": "2" },
    "29-STOCKTON": { "ABC220": "36", "ABC61": "16", "TOTAL": "52" },
    "31-REDDING": { "ABC220": "9", "ABC61": "4", "TOTAL": "13" }
    //"40-CONCORD": { "ABC220": "0", "ABC61": "0", "TOTAL": "0" },
    //"53-GAP NORTHERN": { "ABC220": "0", "ABC61": "0", "TOTAL": "0" }
};


$(document).ready(function ()
{
    var ctx;
    var sp;
    var br;
    var pi;
    var tmp = {};
    var data3 = data2; //jQuery.parseJSON(data2);
    var key // = Object.keys(data3[0])[0];  //data3['DATA'][Object.keys(data3['DATA'])].ABC61
    var i = 20;

    data = {}
    for (key in data3)
    {
        //key = Object.keys(data3[i])[0];
        tmp = new Object();
        tmp['TOTAL'] = data3[key].TOTAL;
        tmp['TEXT'] = key;
        tmp['COLOR'] = "#" + colours[(i++ * 3) % colours.length].hex;
        data[key] = tmp;
    }

    ctx = createCanvas('odometer')
    ctx.canvas.width = 450;
    ctx.canvas.height = 450;
    sp = new speedometer(ctx);
    sp.update(data);

    ctx = createCanvas('pie');
    ctx.canvas.width = 450;
    ctx.canvas.height = 450;
    //ctx.canvas.style.background = '#D0d0d0';
    pi = new piechart(ctx);
    pi.update(data);

    ////for (key in data3)
    //{
    //    data = {};

    //    key = '23-SACRAMENTO'; //Object.keys(data3[i])[0];

    //    tmp = new Object();
    //    tmp['TOTAL'] = data3[key].ABC61;
    //    tmp['TEXT'] = 'ABC61';
    //    tmp['COLOR'] = "#40FF40";
    //    data['ABC61'] = tmp;

    //    tmp = new Object();
    //    tmp['TOTAL'] = data3[key].ABC220;
    //    tmp['TEXT'] = 'ABC220';
    //    tmp['COLOR'] = "#4040FF";
    //    data['ABC220'] = tmp;
    //}


    ////ctx = createCanvas('bar');
    ////ctx.canvas.width = 350;
    ////ctx.canvas.height = 450;
    //////ctx.canvas.style.background = '#D0d0d0';
    //br = new bargraph('bar_canvas', true);
    //br.update(data);
});

function pie_onClick(e, canvas, items)
{
    var centerX = e.target.width / 2;
    var centerY = e.target.height / 2;
    var x       = e.offsetX;
    var y       = e.offsetY;
    var fromX   = x - centerX;
    var fromY   = y - centerY;
    var radius;
    var angle;
    var key;
    var item;
    var data;

    // check if inside pie
    radius = Math.sqrt(Math.pow(Math.abs(fromX), 2) + Math.pow(Math.abs(fromY), 2));
    if (canvas.radius > radius)
    {
        // find which item was clicked on.
        angle = Math.atan2(fromY, fromX);
        if (angle < 0) angle = 2 * Math.PI + angle;

        for (key in items)
        {
            if ((angle >= items[key].START) && (angle < items[key].END)) break;
        }

        // display in bar chart
        data = {};

        tmp = new Object();
        tmp['TOTAL'] = data2[key].ABC61;
        tmp['TEXT'] = 'ABC61';
        tmp['COLOR'] = "#40FF40";
        data['ABC61'] = tmp;

        tmp = new Object();
        tmp['TOTAL'] = data2[key].ABC220;
        tmp['TEXT'] = 'ABC220';
        tmp['COLOR'] = "#4040FF";
        data['ABC220'] = tmp;

        br = new bargraph('bar_canvas', 'Summary of ABC-61 and ABC-220 counts', key, true);
        br.update(data);

        jQuery('#main-dashboard').hide();
        jQuery('#sub-dashboard').show();
    }

    //alert(key);
}

function createCanvas(divName)
{

    var div = document.getElementById(divName);
    var canvas = document.createElement('canvas');                                                                              

    //canvas.onclick = function (e) { pie_onClick(e); }

    //canvas.style.border = "black 1px solid";
    //canvas.style.background = "#000000"
    div.appendChild(canvas);
    return canvas.getContext("2d");

}


function piechart(context)
{
    // private properties and methods
    var m_this = this;
    var m_context = context;
    var m_arcStart = 0.75;
    var m_arcEnd = 0.25;

    var draw = function (items)
    {
        var inx;
        var total = 0;
        var ratio;
        var start = 0;
        var end = 0;
        var key;


//        $(m_this).mousedown(function (e) { pie_onClick(e); });
//        m_this.onclick = function (e) { pie_onClick(e); }

        m_context.canvas.onclick = function (e) { pie_onClick(e, m_this, items); }


        m_maxHeight = m_context.canvas.height - 15;
        m_maxWidth = m_context.canvas.width - 50;

        m_context.translate(m_context.canvas.width / 2, m_context.canvas.height / 2)

//        m_context.fillStyle = "#333";
        m_context.font = "bold 12px sans-serif";

        // 
//        for (i = 0; i < items.length; i += 1)
        for (key in items)
        {
            total += parseInt(items[key].TOTAL);
        }

        create_background();
        ratio = 2 / total;

//        for (i = 0; i < items.length; i += 1)
        for (key in items)
        {
            start = end;
            end = start + (ratio * parseInt(items[key].TOTAL));

            items[key].START = start * Math.PI;
            items[key].END = end * Math.PI;
            create_pie(items[key], start, end);
        }


        //create_background();

        //m_context.lineWidth = m_this.line_width;
        //create_arc(m_arcStart, 1.75, 'green', 'round');
        //create_arc(0, m_arcEnd, 'red', 'round');
        //create_arc(1.75, 0, 'yellow', 'block');

        //add_number(30, 0, 150);
        //add_hash(30);

//        position_needle(value, 100);
    }

    var create_background = function ()
    {
        var grd;

        m_context.save();

        m_context.beginPath();
        m_context.arc(0, 0, 0, 0, 2 * Math.PI, false);
        m_context.fillStyle = m_this.background;
        m_context.fill();

        m_context.strokeStyle = "black";
        m_context.lineWidth = 2;
        m_context.stroke();

        //grd = m_context.createRadialGradient(0, 0, 150, 0, 0, 175);
        //grd.addColorStop(0.2, "rgba(0,255,0,.2)");
        //grd.addColorStop(0.5, "rgba(255,255,255,.7)");
        //grd.addColorStop(0.8, "black");

        //m_context.strokeStyle = grd;
        //m_context.stroke();
        m_context.restore();
    }

    //var position_needle = function (value, maxValue)
    //{
    //    var radians;
    //    var x;
    //    var y;
    //    var grd;

    //    m_context.save();

    //    m_context.beginPath();
    //    m_context.arc(0, 0, 25, 0, 2 * Math.PI, false);
    //    m_context.fillStyle = "black";
    //    m_context.fill();

    //    // convert value to radians
    //    radians = (((((2 - (m_arcStart - m_arcEnd)) / maxValue) * value) + m_arcStart) % 2) * Math.PI;

    //    x = Math.cos(radians);
    //    y = Math.sin(radians);

    //    //m_context.beginPath();
    //    //m_context.moveTo(300, 300);
    //    //grd = m_context.createLinearGradient(100, 10, -100, -10);

    //    //grd = m_context.createLinearGradient(-(m_this.radius) * x, 30, (m_this.radius) * x, (m_this.radius) * y);
    //    //grd = m_context.createLinearGradient(14.2, -0, -m_this.radius * y, (m_this.radius) * x + 90);
    //    //grd = m_context.createRadialGradient(0, 0, 0, -220, -130, 10);

    //    //grd.addColorStop(.3, "blue");
    //    //grd.addColorStop(.5, "rgba(255,255,255,1)");
    //    //grd.addColorStop(.7, "blue");

    //    m_context.beginPath();
    //    m_context.lineCap = 'round';
    //    m_context.lineWidth = 5;
    //    m_context.strokeStyle = 'blue';
    //    m_context.moveTo(0, 0);

    //    // line 1
    //    m_context.lineTo(((m_this.radius + 15) * x), ((m_this.radius + 15) * y));
    //    m_context.stroke();
    //    m_context.restore();
    //}

    // 0 - 2 PI (s, e)
    var create_pie = function (item, start, end)
    {
        m_context.save();

        m_context.lineWidth = 1;
        m_context.strokeStyle = 'black';

        m_context.beginPath();
        m_context.moveTo(0, 0);
        m_context.arc(0, 0, m_this.radius, start * Math.PI, end * Math.PI, m_this.counter_clockwise);
        m_context.closePath;
        m_context.fillStyle = item.COLOR;
        m_context.fill();
        m_context.stroke();

        add_line(start * Math.PI);
        add_line(end * Math.PI);

        add_number(item, start, end);

        m_context.restore();
    }

        // start - end  Math.PI values 0 to 2
    var create_arc = function (start, end, color, end_cap)
    {
        m_context.save();

        var grd = m_context.createRadialGradient(0, 0, m_this.radius - 10, 0, 0, m_this.radius + 10);
        grd.addColorStop(0.2, color);
        grd.addColorStop(.5, "rgba(255,255,255,0.5)");
        grd.addColorStop(.8, color);

        // Fill with gradient
        m_context.fillStyle = grd;

        m_context.beginPath();
        m_context.arc(0, 0, m_this.radius, start * Math.PI, end * Math.PI, m_this.counter_clockwise);
        m_context.strokeStyle = grd; //color;
        m_context.lineCap = end_cap;
        m_context.stroke();
        //m_context.fill();
        m_context.restore();
    }

    var add_number = function (item, start, end)
    {
        var x;
        var y;
        var value;
        var offset;
        var angle;

        m_context.save();

        offset = (end - start) / 2;
        x = Math.cos((start + offset) * Math.PI);
        y = Math.sin((start + offset) * Math.PI);

        m_context.fillStyle = "#FFFFFF";
        m_context.textAlign = "center"
        m_context.fillText(item.TOTAL, (m_this.radius - 15) * x, (m_this.radius - 15) * y);

        angle = ((start + offset) * Math.PI) * (180 / Math.PI);
        //angle = angle > 180 ? angle * Math.PI / 180  : angle * Math.PI / 180 ;
        m_context.fillStyle = "#FFF";
        m_context.translate((m_this.radius + 5) * x, (m_this.radius + 5) * y); // x - add to x corr y - add to corr
        if (angle > 90 && angle < 270)
        {
            angle -= 180;
            m_context.textAlign = "right"
        }
        else
        {
            m_context.textAlign = "left"
        }

        m_context.rotate(angle * Math.PI / 180);
        m_context.fillText(item.TEXT.substr(0, 7), 0, 0);


        m_context.restore();
    }

    var add_line = function (radians)
    {
        var x;
        var y;
        var inx;

        m_context.save();

        x = Math.cos(radians);
        y = Math.sin(radians);

        m_context.beginPath();
        m_context.lineWidth = 1;
        m_context.strokeStyle = 'black';

        m_context.moveTo(0, 0);
        // line 1
        m_context.lineTo(x * (m_this.radius),
                         y * (m_this.radius));
        m_context.stroke();

        m_context.restore();
    }


    // public properties and methods
    this.line_width = 20;   // default 20
    this.counter_clockwise = false;
    this.radius = 150;
    this.background = "#d0d0d0";

    this.update = function (value)
    {
        draw(value);
    }
}


function speedometer(context)
{
    // private properties and methods
    var m_this = this;
    var m_context = context;
    var m_arcStart = 0.75;
    var m_arcEnd   = 0.25;

    var draw = function (items)
    {
        var total = 0;
        var high  = 0;
        var low   = 1000;
        var value;
        var avg;
        var inc;
        var key;
        var cnt = 0;

        m_context.translate(m_context.canvas.width / 2, m_context.canvas.height / 2)

        for (key in items)
//            for (i = 0; i < items.length; i += 1)
        {
            value = parseInt(items[key].TOTAL);
            total += value;
            if (value >= high) high = value;
            if (value <= low) low = value;
            cnt++;
        }

        high = Math.ceil(high / 10) * 10;
        low = Math.floor(low / 10) * 10;
        avg = total / cnt;
        inc = ((high - low) / 10) * 2;

        create_background();

        m_context.lineWidth = m_this.line_width;
        create_arc(m_arcStart, 1.75, 'green', 'round');
        create_arc(0, m_arcEnd, 'red', 'round');
        create_arc(1.75, 0, 'yellow', 'block');

        add_number(inc, low, high);
        add_hash(inc);

        position_needle(avg, high + low);

        m_context.font = "bold 8pt sans-serif";
        m_context.fillStyle = "white";
        m_context.textAlign = 'center';
        m_context.fillText('Combined Departmental Average of Enforcement ABC- 61 and ABC-220 Assignments',
                            0,
                            m_this.radius * 2 + 20);


    }

    var create_background = function ()
    {
        var grd;

        m_context.save();

        m_context.beginPath();
        m_context.arc(0, 0, m_this.radius + 60, 0, 2 * Math.PI, false);
        m_context.fillStyle = m_this.background;
        m_context.fill();

        m_context.strokeStyle = "black";
        m_context.lineWidth = 20;
        m_context.stroke();

        grd = m_context.createRadialGradient(0, 0, 130, 0, 0, 155);
        grd.addColorStop(0.2, "rgba(0,255,0,.2)");
        grd.addColorStop(0.5, "rgba(255,255,255,.7)");
        grd.addColorStop(0.8, "black");

        m_context.strokeStyle = grd;
        m_context.stroke();
        m_context.restore();
    }

    var position_needle = function (value, maxValue)
    {
        var radians;
        var x;
        var y;

        var rx;
        var ry;
        var rw;
        var rh;
        var rr = m_this.radius + 10;
        var w;
        var h;
        var grd;

        m_context.save();

        // figure out rectangle size
        radians = ((m_arcStart * 180) - 15) / 180 * Math.PI;
        rx = Math.cos(radians) * rr;
        ry = Math.sin(radians) * rr;
        rw = (Math.cos(((m_arcEnd * 180) + 15) / 180 * Math.PI) * rr)
           - (Math.cos(((m_arcStart * 180) - 15) / 180 * Math.PI) * rr);
        rh = 20;

        m_context.beginPath();
        m_context.arc(0, 0, 15, 0, 2 * Math.PI, false);
        m_context.fillStyle = "black";
        m_context.fill();

        // convert value to radians
        radians = (((((2 - (m_arcStart - m_arcEnd)) / maxValue) * (value + .75)) + (m_arcStart - (2.5 / 180))) % 2) * Math.PI;

        x = Math.cos(radians);
        y = Math.sin(radians);

        m_context.beginPath();
        m_context.lineCap = 'round';
        m_context.lineWidth = 5;
        m_context.strokeStyle = 'blue';
        m_context.moveTo(0, 0);

        // line 
        m_context.lineTo(((m_this.radius + 12) * x), ((m_this.radius + 12) * y));
        m_context.stroke();

        //radians = m_arcStart * Math.PI;
        //x = Math.cos(radians);
        //y = Math.sin(radians);

        m_context.fillStyle = "#000";
        m_context.fillRect(rx, ry, rw, rh);

        m_context.fillStyle = "#FFF";
        m_context.beginPath();
        m_context.font = "bold 14px sans-serif";
        m_context.textAlign = "right";
        
        //radians = m_arcEnd * Math.PI;
        //x = Math.cos(radians);
        //y = Math.sin(radians);
        m_context.fillText((parseInt(value * 100) / 100).toString(), rx + rw - 5, ry + rh - 5)

        m_context.restore();
    }

    // start - end  Math.PI values 0 to 2
    var create_arc = function (start, end, color, end_cap)
    {
        m_context.save();

        var grd = m_context.createRadialGradient(0, 0, m_this.radius - 10, 0, 0, m_this.radius + 10);
        grd.addColorStop(0.2, color);
        grd.addColorStop(.5, "rgba(255,255,255,0.5)");
        grd.addColorStop(.8, color);

        // Fill with gradient
        m_context.fillStyle = grd;

        m_context.beginPath();
        m_context.arc(0, 0, m_this.radius, start * Math.PI, end * Math.PI, m_this.counter_clockwise);
        m_context.strokeStyle = grd; //color;
        m_context.lineCap = end_cap;
        m_context.stroke();
        //m_context.fill();
        m_context.restore();
    }

    var add_number = function (inc, startValue, maxValue)
    {
        var x;
        var y;
        var radians = m_arcStart * Math.PI;
        var currAngle
        var changeAngle = ((2 - (m_arcStart - m_arcEnd)) / inc) * Math.PI;
        var changeValue = (maxValue - startValue) / inc;
        var inx;
        var value;

        m_context.save();

        for (inx = 0; inx <= inc; inx++)
        {
            value = startValue + (changeValue * inx);
            x = Math.cos(radians);
            y = Math.sin(radians);

            m_context.textAlign = "center";
            m_context.fillText(value.toString(), (m_this.radius + 25) * x, (m_this.radius + 25) * y);

            radians += changeAngle
        }

        m_context.restore();
    }

    var add_hash = function (inc)
    {
        var x;
        var y;
        var radians = m_arcStart * Math.PI;
        var changeAngle = ((2 - (m_arcStart - m_arcEnd)) / inc) * Math.PI;
        var inx;

        m_context.save();

        for (inx = 0; inx <= inc; inx++)
        {
            x = Math.cos(radians);
            y = Math.sin(radians);

            m_context.beginPath();
            m_context.lineWidth = 1;
            m_context.strokeStyle = 'black';

            m_context.moveTo(x * (m_this.radius - (m_this.line_width / 2)), 
                             y * (m_this.radius - (m_this.line_width / 2)));
            // line 1
            m_context.lineTo(x * (m_this.radius + (m_this.line_width / 2)), 
                             y * (m_this.radius + (m_this.line_width / 2)));
            m_context.stroke();
            
            radians += changeAngle
        }

        m_context.restore();
    }


    // public properties and methods
    this.line_width = 20;   // default 20
    this.counter_clockwise = false;
    this.radius = 80;
    this.background = "#d0d0d0";

    this.update = function (items)
    {
        draw(items);
    }
}

function bargraph_old(context)
{
    // private properties and methods
    var m_this = this;
    var m_context = context;
    var m_maxWidth;


    var draw = function (items)
    {
        var inx;
        var margine = 5;
        var bars;
        var max_count = 0;
        var ratio;
        var x;
        var y;
        var w;
        var h;
        var i = 0;

        m_maxHeight = m_context.canvas.height - 15;
        m_maxWidth = m_context.canvas.width - 200;
        bars = Object.keys(items).length;
        h = (m_maxHeight / bars) - margine;

        m_context.fillStyle = "#333";
        m_context.font = "bold 12px sans-serif";

        // get max number
        //for (i = 0; i < items.length; i += 1)
        for (key in items)
        {
            if (parseInt(max_count) < parseInt(items[key].TOTAL)) max_count = items[key].TOTAL;
        }

        create_background();

        //for (i = 0; i < items.length; i += 1)
        for (key in items)
        {
            ratio = parseInt(items[key].TOTAL) / max_count;
            w = m_maxWidth * ratio;
            y = (i * (h + margine)) + margine + 15;
            x = 150 ;
            i++;

            create_bar(items[key], x, y, w, h, ratio);
        }


    }

    var create_background = function ()
    {
        var grd;

        m_context.save();

        m_context.beginPath();

        m_context.restore();
    }

    var create_bar = function (item, x, y, w, h, ratio)
    {
        var start = (150 / m_context.canvas.width);
        var stop  = ((1 - start) * ratio) + start;

        m_context.save();

        // build border
        m_context.fillStyle = "black";
        m_context.fillRect(x, y, w, h); // x, y, width, hight (xy upper left conner)

        grd = m_context.createLinearGradient(0, 0, m_context.canvas.width, 0);
        grd.addColorStop(stop, item.COLOR);
        grd.addColorStop(start, "white");

        m_context.fillStyle = grd;
        m_context.fillRect(x + 1, y + 1, w - 2, h - 2); // x, y, width, hight (xy upper left conner)

        m_context.fillStyle = "black";
        m_context.fillText(item.TOTAL, x + w + 10, y + (h / 2) + 4);

        m_context.fillStyle = "#fff";
        m_context.textAlign = 'right';
        m_context.fillText(item.TEXT, x - 10, y + h - 2);

        m_context.restore();


    }


    // public properties and methods
    this.background = "#d0d0d0";

    this.update = function (value)
    {
        draw(value);
    }

}