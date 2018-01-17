$('nav').on('click', function () {
    $('nav').toggleClass('nav-expanded')
});

$(document).bind("DOMNodeRemoved", function (e) {
    if (e.target.className == 'dialog-ux') {
        $('html, body').css('overflow', 'visible');
    }
});

$(document).bind("DOMNodeInserted", function (e) {
    if (e.target.className == 'dialog-ux') {
        $('html, body').css('overflow', 'hidden');
    }
});
