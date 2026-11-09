import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Esfera "Pixel Time": hora pixelada que ocupa el maximo de la pantalla
// redonda, con dia de la semana y del mes encima. Dos estilos de digitos.
// Pensada para tactix 8 Solar / fenix 8 Solar (MIP).
class PixelTimeView extends WatchUi.WatchFace {

    // ---- Ajustes ---------------------------------------------------------
    // Tamano de la hora por estilo: 1.0 = toca el borde de la pantalla,
    // valores menores dejan margen.
    // Con 280 px: redondeado 0.93 -> 60 px de alto, anguloso 0.89 -> 70 px.
    const SIZE_RATIO_ROUND = 0.93;
    const SIZE_RATIO_ANGULAR = 0.89;
    // Mostrar los dos puntos entre horas y minutos.
    const SHOW_COLON = true;
    // Bloques de separacion entre caracteres de la hora, por estilo.
    const SPACING_ROUND = 1;
    const SPACING_ANGULAR = 1;
    // Tamano del bloque de la fecha respecto al bloque de referencia.
    const DATE_SCALE = 0.4;
    // Hueco entre la fecha y la hora, en bloques de referencia.
    const DATE_GAP = 2;
    // ----------------------------------------------------------------------

    const GLYPH_H = 5;

    // Etiquetas por dia de la semana (Gregorian: 1 = domingo ... 7 = sabado).
    const DAY_LABELS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

    // Cada glifo: [ancho, fila0..fila4, (columna, fila*2)...]. Cada fila es
    // una mascara de bits, el bit mas alto es la columna izquierda. Los pares
    // opcionales del final son bloques sueltos con posicion vertical en
    // medios bloques, para colocarlos entre dos filas.

    // Estilo redondeado: digitos 4x5, esquinas escalonadas. Tambien se usa
    // para la fecha.
    private var _fontRound as Dictionary<String, Array<Number>>;
    // Estilo anguloso: digitos 3x5, todos a la altura del 8.
    private var _fontAngular as Dictionary<String, Array<Number>>;

    // Calendario del mes: se muestra al mantener pulsada la pantalla y se
    // oculta al volver a pulsar o cuando el reloj vuelve al reposo.
    var showCalendar as Boolean = false;
    // Meses de desplazamiento respecto al actual (-1 anterior, +1 siguiente).
    var monthOffset as Number = 0;

    const MONTH_LABELS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                          "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    const WEEK_LABELS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
    const MONTH_DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    // Digitos pequenos 3x5 para los dias del calendario.
    private var _fontSmall as Dictionary<String, Array<Number>>;

    function initialize() {
        WatchFace.initialize();
        _fontRound = {
            "0" => [4, 0x6, 0x9, 0x9, 0x9, 0x6], // .##. #..# #..# #..# .##.
            // Palo vertical + cuadrado lateral a media altura entre fila 1 y 2
            // (bloque extra: columna 1, fila 3/2).
            "1" => [4, 0x2, 0x2, 0x2, 0x2, 0x2, 1, 3],
            "2" => [4, 0x6, 0x9, 0x2, 0x4, 0xF], // .##. #..# ..#. .#.. ####
            "3" => [4, 0xE, 0x1, 0x6, 0x1, 0xE], // ###. ...# .##. ...# ###.
            "4" => [4, 0x9, 0x9, 0xF, 0x1, 0x1], // #..# #..# #### ...# ...#
            "5" => [4, 0xF, 0x8, 0xE, 0x1, 0xE], // #### #... ###. ...# ###.
            "6" => [4, 0x6, 0x8, 0xE, 0x9, 0x6], // .##. #... ###. #..# .##.
            "7" => [4, 0xF, 0x1, 0x2, 0x4, 0x4], // #### ...# ..#. .#.. .#..
            "8" => [4, 0x6, 0x9, 0x6, 0x9, 0x6], // .##. #..# .##. #..# .##.
            "9" => [4, 0x6, 0x9, 0x7, 0x1, 0x6], // .##. #..# .### ...# .##.
            ":" => [1, 0x0, 0x1, 0x0, 0x1, 0x0],
            " " => [1, 0x0, 0x0, 0x0, 0x0, 0x0],
            "M" => [5, 0x11, 0x1B, 0x15, 0x11, 0x11], // #...# ##.## #.#.# #...# #...#
            "W" => [5, 0x11, 0x11, 0x15, 0x1B, 0x11], // #...# #...# #.#.# ##.## #...#
            "O" => [4, 0x6, 0x9, 0x9, 0x9, 0x6],      // .##. #..# #..# #..# .##.
            "T" => [3, 0x7, 0x2, 0x2, 0x2, 0x2],      // ### .#. .#. .#. .#.
            "U" => [4, 0x9, 0x9, 0x9, 0x9, 0x6],      // #..# #..# #..# #..# .##.
            "E" => [4, 0xF, 0x8, 0xE, 0x8, 0xF],      // #### #... ###. #... ####
            "H" => [4, 0x9, 0x9, 0xF, 0x9, 0x9],      // #..# #..# #### #..# #..#
            "F" => [4, 0xF, 0x8, 0xE, 0x8, 0x8],      // #### #... ###. #... #...
            "R" => [4, 0xE, 0x9, 0xE, 0xA, 0x9],      // ###. #..# ###. #.#. #..#
            "S" => [4, 0x7, 0x8, 0x6, 0x1, 0xE],      // .### #... .##. ...# ###.
            "A" => [4, 0x6, 0x9, 0xF, 0x9, 0x9],      // .##. #..# #### #..# #..#
            "N" => [4, 0x9, 0xD, 0xB, 0x9, 0x9],      // #..# ##.# #.## #..# #..#
            "B" => [4, 0xE, 0x9, 0xE, 0x9, 0xE],      // ###. #..# ###. #..# ###.
            "P" => [4, 0xE, 0x9, 0xE, 0x8, 0x8],      // ###. #..# ###. #... #...
            "L" => [4, 0x8, 0x8, 0x8, 0x8, 0xF],      // #... #... #... #... ####
            "G" => [4, 0x7, 0x8, 0xB, 0x9, 0x7],      // .### #... #.## #..# .###
            "C" => [4, 0x7, 0x8, 0x8, 0x8, 0x7],      // .### #... #... #... .###
            "D" => [4, 0xE, 0x9, 0x9, 0x9, 0xE],      // ###. #..# #..# #..# ###.
            "J" => [4, 0x1, 0x1, 0x1, 0x9, 0x6],      // ...# ...# ...# #..# .##.
            "Y" => [5, 0x11, 0x0A, 0x04, 0x04, 0x04], // #...# .#.#. ..#.. ..#.. ..#..
            "V" => [5, 0x11, 0x11, 0x11, 0x0A, 0x04], // #...# #...# #...# .#.#. ..#..
            "<" => [3, 0x1, 0x2, 0x4, 0x2, 0x1],      // ..# .#. #.. .#. ..#
            ">" => [3, 0x4, 0x2, 0x1, 0x2, 0x4]       // #.. .#. ..# .#. #..
        } as Dictionary<String, Array<Number>>;

        _fontSmall = {
            "0" => [3, 0x7, 0x5, 0x5, 0x5, 0x7], // ### #.# #.# #.# ###
            "1" => [3, 0x2, 0x6, 0x2, 0x2, 0x7], // .#. ##. .#. .#. ###
            "2" => [3, 0x7, 0x1, 0x7, 0x4, 0x7], // ### ..# ### #.. ###
            "3" => [3, 0x7, 0x1, 0x3, 0x1, 0x7], // ### ..# .## ..# ###
            "4" => [3, 0x5, 0x5, 0x7, 0x1, 0x1], // #.# #.# ### ..# ..#
            "5" => [3, 0x7, 0x4, 0x7, 0x1, 0x7], // ### #.. ### ..# ###
            "6" => [3, 0x7, 0x4, 0x7, 0x5, 0x7], // ### #.. ### #.# ###
            "7" => [3, 0x7, 0x1, 0x2, 0x2, 0x2], // ### ..# .#. .#. .#.
            "8" => [3, 0x7, 0x5, 0x7, 0x5, 0x7], // ### #.# ### #.# ###
            "9" => [3, 0x7, 0x5, 0x7, 0x1, 0x7]  // ### #.# ### ..# ###
        } as Dictionary<String, Array<Number>>;

        _fontAngular = {
            "0" => [3, 0x7, 0x5, 0x5, 0x5, 0x3], // ### #.# #.# #.# .##
            "1" => [3, 0x2, 0x6, 0x2, 0x2, 0x2], // .#. ##. .#. .#. .#.
            "2" => [3, 0x6, 0x2, 0x2, 0x4, 0x6], // ##. .#. .#. #.. ##.
            "3" => [3, 0x6, 0x3, 0x1, 0x1, 0x6], // ##. .## ..# ..# ##.
            "4" => [3, 0x5, 0x5, 0x5, 0x6, 0x1], // #.# #.# #.# ##. ..#
            "5" => [3, 0x7, 0x4, 0x2, 0x2, 0x6], // ### #.. .#. .#. ##.
            "6" => [3, 0x4, 0x4, 0x7, 0x5, 0x3], // #.. #.. ### #.# .##
            "7" => [3, 0x7, 0x1, 0x2, 0x2, 0x2], // ### ..# .#. .#. .#.
            "8" => [3, 0x7, 0x5, 0x2, 0x5, 0x7], // ### #.# .#. #.# ###
            "9" => [3, 0x6, 0x5, 0x7, 0x1, 0x1], // ##. #.# ### ..# ..#
            ":" => [1, 0x0, 0x1, 0x0, 0x1, 0x0]
        } as Dictionary<String, Array<Number>>;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        var bg = isDarkMode() ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        var fg = isDarkMode() ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(bg, bg);
        dc.clear();
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        if (showCalendar) {
            drawCalendar(dc, w, h);
            return;
        }

        var angular = getStyle() == STYLE_ANGULAR;
        var font = angular ? _fontAngular : _fontRound;
        var spacing = angular ? SPACING_ANGULAR : SPACING_ROUND;
        var radius = (w < h ? w : h) / 2.0;

        // ---- Hora ----
        var settings = System.getDeviceSettings();
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!settings.is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var time = (settings.is24Hour ? hour.format("%02d") : hour.toString())
            + (SHOW_COLON ? ":" : "")
            + clock.min.format("%02d");

        var block = fitBlock(radius * (angular ? SIZE_RATIO_ANGULAR : SIZE_RATIO_ROUND), angular ? 3 : 4, spacing);
        var timeW = measure(font, time, spacing) * block;
        var timeY = (h - GLYPH_H * block) / 2;
        drawText(dc, font, time, (w - timeW) / 2, timeY, block, spacing);

        // ---- Fecha: "MO 12", "TH 3"... ----
        // Su tamano no depende del estilo, para que quepa siempre.
        // Base fija (digitos de 4 con huecos de 2) para que la fecha conserve
        // su tamano aunque cambien los huecos de la hora.
        var base = fitBlock(radius, 4, 2);
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var date = DAY_LABELS[(info.day_of_week as Number) - 1] + " " + info.day.toString();

        var dBlock = Math.round(base * DATE_SCALE).toNumber();
        if (dBlock < 1) {
            dBlock = 1;
        }
        var dateW = measure(_fontRound, date, 1) * dBlock;
        var dateY = timeY - DATE_GAP * base - GLYPH_H * dBlock;
        drawText(dc, _fontRound, date, (w - dateW) / 2, dateY, dBlock, 1);
    }

    // Dia de la semana (0 = domingo ... 6 = sabado), algoritmo de Sakamoto.
    private function dayOfWeek(y as Number, m as Number, d as Number) as Number {
        var t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
        if (m < 3) {
            y -= 1;
        }
        return (y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7;
    }

    // Mes completo (semana de lunes a domingo) con el dia de hoy subrayado.
    private function drawCalendar(dc as Dc, w as Number, h as Number) as Void {
        var p = (w >= 240) ? 3 : 2;  // bloque de los numeros
        var wp = p - 1;              // bloque de las iniciales de la semana
        var cellW = 7 * p;           // dos digitos de 3 + 1 de hueco
        var pitch = cellW + 3 * p;   // ancho de columna con separacion
        var gridW = 7 * pitch - 3 * p;
        var rowH = 8 * p;            // 5 de digito + hueco + subrayado + hueco

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        // Mes mostrado = mes actual + monthOffset.
        var total = (info.year as Number) * 12 + (info.month as Number) - 1 + monthOffset;
        var year = total / 12;
        var month = total % 12 + 1;
        // El subrayado solo aparece en el mes actual.
        var day = (monthOffset == 0) ? info.day as Number : 0;

        var days = MONTH_DAYS[month - 1];
        if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
            days = 29;
        }
        // Columna del dia 1 (0 = lunes).
        var firstCol = (dayOfWeek(year, month, 1) + 6) % 7;

        // Altura calculada siempre para 6 semanas (el maximo), para que la
        // cabecera no salte al pasar entre meses de 4, 5 o 6 filas.
        var totalH = 5 * p + 3 * p + 5 * wp + 3 * p + 6 * rowH - 3 * p;
        var y = (h - totalH) / 2;
        var left = (w - gridW) / 2;

        // Cabecera: "< NOV 2026 >". Las flechas marcan las zonas de pulsacion.
        var title = MONTH_LABELS[month - 1] + " " + year.toString();
        drawText(dc, _fontRound, title, (w - measure(_fontRound, title, 1) * p) / 2, y, p, 1);
        drawText(dc, _fontRound, "<", left, y, p, 1);
        drawText(dc, _fontRound, ">", left + gridW - 3 * p, y, p, 1);
        y += 8 * p;

        // Iniciales de la semana
        for (var c = 0; c < 7; c++) {
            var lw = measure(_fontRound, WEEK_LABELS[c], 1) * wp;
            drawText(dc, _fontRound, WEEK_LABELS[c], left + c * pitch + (cellW - lw) / 2, y, wp, 1);
        }
        y += 5 * wp + 3 * p;

        // Dias
        for (var d = 1; d <= days; d++) {
            var idx = firstCol + d - 1;
            var cx = left + (idx % 7) * pitch;
            var cy = y + (idx / 7) * rowH;
            var s = d.toString();
            var tw = measure(_fontSmall, s, 1) * p;
            var tx = cx + (cellW - tw) / 2;
            drawText(dc, _fontSmall, s, tx, cy, p, 1);
            if (d == day) {
                dc.fillRectangle(cx, cy + 6 * p, cellW, p);
            }
        }
    }

    // Mayor bloque con el que la hora (siempre calculada para 4 digitos, asi
    // el tamano no cambia entre 9:59 y 10:00) cabe dentro del circulo.
    private function fitBlock(radius as Float, digitW as Number, spacing as Number) as Number {
        var maxBlocks = 4 * digitW + 3 * spacing;
        if (SHOW_COLON) {
            maxBlocks += 1 + spacing;
        }
        var halfW = maxBlocks / 2.0;
        var halfH = GLYPH_H / 2.0;
        // +0.5 px de tolerancia: como mucho se recortan 2-3 pixeles de la
        // esquina exterior de un bloque, imperceptible.
        var block = ((radius + 0.5) / Math.sqrt(halfW * halfW + halfH * halfH)).toNumber();
        return block < 1 ? 1 : block;
    }

    // Ancho en bloques de un texto.
    private function measure(font as Dictionary<String, Array<Number>>, text as String, spacing as Number) as Number {
        var chars = text.toCharArray();
        var total = 0;
        for (var i = 0; i < chars.size(); i++) {
            var g = font[chars[i].toString()];
            if (g != null) {
                total += g[0];
                if (i > 0) {
                    total += spacing;
                }
            }
        }
        return total;
    }

    private function drawText(dc as Dc, font as Dictionary<String, Array<Number>>, text as String,
                              x as Number, y as Number, block as Number, spacing as Number) as Void {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var g = font[chars[i].toString()];
            if (g != null) {
                drawGlyph(dc, g, x, y, block);
                x += (g[0] + spacing) * block;
            }
        }
    }

    private function drawGlyph(dc as Dc, g as Array<Number>, x as Number, y as Number, block as Number) as Void {
        var gw = g[0];
        for (var r = 0; r < GLYPH_H; r++) {
            var bits = g[r + 1];
            // Junta los bloques contiguos de la fila en un solo rectangulo.
            var col = 0;
            while (col < gw) {
                if ((bits & (1 << (gw - 1 - col))) != 0) {
                    var start = col;
                    while (col < gw && (bits & (1 << (gw - 1 - col))) != 0) {
                        col++;
                    }
                    dc.fillRectangle(x + start * block, y + r * block, (col - start) * block, block);
                } else {
                    col++;
                }
            }
        }
        for (var i = GLYPH_H + 1; i + 1 < g.size(); i += 2) {
            dc.fillRectangle(x + g[i] * block, y + (g[i + 1] * block) / 2, block, block);
        }
    }

    // En MIP la esfera se refresca una vez por minuto; no hace falta nada mas.
    function onEnterSleep() as Void {
        if (showCalendar) {
            showCalendar = false;
            monthOffset = 0;
            WatchUi.requestUpdate();
        }
    }

    function onExitSleep() as Void {
    }
}
