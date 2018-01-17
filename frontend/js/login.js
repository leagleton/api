$(document).ready(function () {
    $('div[data-role="input"]').each(function () {
        const element = $(this);
        const input = element.find('input');
        const placeholder = element.find('.placeholder');

        if (input.val() !== '') {
            placeholder.css({ display: 'none' });
        }

        input.on('blur', function () {
            if (input.val() !== '') {
                placeholder.css({ display: 'none' });
            } else {
                placeholder.css({ display: 'block' });
            }
        });
        input.on('change', function () {
            if (input.val() !== '') {
                placeholder.css({ display: 'none' });
            } else {
                placeholder.css({ display: 'block' });
            }
        });
        input.on('focus', function () {
            if (input.val() !== '') {
                placeholder.css({ display: 'none' });
            } else {
                placeholder.css({ display: 'block' });
            }
        });
    });
});
