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

$(document).bind("DOMNodeInserted", function (e) {
    if (e.target.className == 'errors') {
        $('.modal-ux-content').scrollTop($('.modal-ux-content')[0].scrollHeight);
    }
});

$('body').on('click', '.auth-btn-wrapper .btn-success', function (e) {
    if ($('#website').val() === "0") {
        e.preventDefault();
        e.stopPropagation();
        $('#website').addClass('has-error');
        $('.modal-ux-content').scrollTop(0);
    }
    if ($('#client_id').val() === '') {
        e.preventDefault();
        e.stopPropagation();
        $('#client_id').addClass('has-error');
        $('.modal-ux-content').scrollTop(0);
    }
    if ($('#client_secret').val() === '') {
        e.preventDefault();
        e.stopPropagation();
        $('#client_secret').addClass('has-error');
        $('.modal-ux-content').scrollTop(0);
    }        
});

$('body').on('focus', '#website', function() {
    if ($(this).hasClass('has-error')) {
        $(this).removeClass('has-error');
    }
});

$('body').on('focus', '#client_id', function() {
    if ($(this).hasClass('has-error')) {
        $(this).removeClass('has-error');
    }
});

$('body').on('focus', '#client_secret', function() {
    if ($(this).hasClass('has-error')) {
        $(this).removeClass('has-error');
    }
});

