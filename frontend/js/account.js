function confirmDelete(elem) {
    const client = $(elem).closest('.clientRow').attr('data-client');
    $('#deleteClient').on('click', function () {
        deleteClient(client);
        $('#deleteClient').off();
    });
    $('#deleteModal').modal('show');
}

function deleteClient(client) {
    $('#deleteModal').modal('hide');
    $('.continue').prop('checked', false);
    $('#deleteClient').prop('disabled', true);

    $.ajax({
        method: "GET",
        url: "clients",
        data: {
            "action": "delete",
            "client": client
        }
    })
        .done(function (results) {
            $('tr[data-client="' + client + '"]').remove();
        });
};

function confirmRevoke(elem) {
    const token = $(elem).closest('.tokenRow').attr('data-token');
    $('#revokeToken').on('click', function () {
        revokeToken(token);
        $('#revokeToken').off();
    });
    $('#revokeModal').modal('show');
}

function revokeToken(token) {
    $('#revokeModal').modal('hide');
    $('.continue').prop('checked', false);
    $('#revokeToken').prop('disabled', true);

    $.ajax({
        method: "GET",
        url: "userAccessTokens",
        data: {
            "action": "delete",
            "token": token
        }
    })
        .done(function (results) {
            $('tr[data-token="' + token + '"]').remove();
        });
};

function fetchClients() {
    $.ajax({
        method: "GET",
        url: "clients",
        cache: false
    })
        .done(function (results) {
            let clients = '<thead><tr><th>Client ID</th><th>Client Secret</th><th>Scopes</th><th>Actions</th></tr></thead>';

            const dbClients = results.map((result) => {
                return new Promise((resolve) => {
                    const scopeIds = result.Scopes.split(',');
                    const readableScopes = [];

                    const scopes = scopeIds.map((scopeId) => {
                        return new Promise((resolve) => {
                            if (readableScopes.push(dbScopes[scopeId])) {
                                resolve();
                            }
                        });
                    });

                    Promise.all(scopes).then(() => {
                        clients += '<tr data-client="' + result.RestApiClient + '" class="clientRow"><td>' + result.RestApiClientId + '</td><td>' + result.Secret + '</td><td>' + readableScopes.join('<br/>') + '</td><td class="actions"><button class="btn btn-danger">Delete</button><button class="btn btn-success">Get Token</button></td></tr>';

                        const client = {
                            "clientId": result.RestApiClientId,
                            "clientSecret": result.Secret,
                            "scopes": readableScopes.join(','),
                            "redirectUri": result.RedirectURI
                        }
                        userClients[result.RestApiClient] = client;

                        resolve();
                    });
                });
            });

            Promise.all(dbClients).then(() => {
                $('#userClients').html(clients);

                $('.clientRow td:nth-of-type(1), .clientRow td:nth-of-type(2)').each(function () {
                    if ($(this).prop('scrollWidth') > $('.access-tokens').prop('scrollWidth')) {
                        $(this).addClass('overflown');
                    }
                });
            });
        });
}

function fetchAccessTokens() {
    $.ajax({
        method: "GET",
        url: "userAccessTokens",
        cache: false
    })
        .done(function (results) {
            let tokens = '<thead><tr><th>Client ID</th><th>Expires</th><th class="actions">Actions</th></tr></thead>';

            const dbTokens = results.map((result) => {
                return new Promise((resolve) => {
                    tokens += '<tr data-token="' + result.RestApiAccessToken + '" class="tokenRow"><td>' + result.RestApiClientId + '</td><td class="expires">' + result.Expires + '</td><td class="actions"><button class="btn btn-danger">Revoke</button></td></tr>';

                    resolve();
                });
            });

            Promise.all(dbTokens).then(() => {
                $('#accessTokens').html(tokens);

                $('.tokenRow td:nth-of-type(1)').each(function () {
                    if ($(this).prop('scrollWidth') > $('.access-tokens').prop('scrollWidth')) {
                        $(this).addClass('overflown');
                    }
                });
            });
        });
}

function getAuthorisationCode(client, website) {
    $.ajax({
        method: "GET",
        url: "oauth/auth",
        cache: false,
        data: {
            "client_id": userClients[client].clientId,
            "redirect_uri": userClients[client].redirectUri,
            "scope": userClients[client].scopes,
            "response_type": "code",
            "response": "ajax",
            "website": website
        }
    })
        .done(function (results) {
            getAccessToken(results, client);
        });
}

function getAccessToken(code, client) {
    $.ajax({
        method: "POST",
        url: "oauth/token",
        cache: false,
        data: {
            "grant_type": "authorization_code",
            "code": code,
            "client_id": userClients[client].clientId,
            "client_secret": userClients[client].clientSecret,
            "redirect_uri": userClients[client].redirectUri
        }
    })
        .done(function (results) {
            $("#requestTokenModal").modal('hide');
            $('#token').html(results.access_token);
            $('#expires').html(results.expires);
            $("#tokenModal").modal('show');

            fetchAccessTokens();
        });
}

function fetchWebsites() {
    $.ajax({
        method: "GET",
        url: "userWebsites",
        cache: false
    })
        .done(function (results) {
            let websitesSelect = '<select name="website" id="website">';

            const dbWebsites = results.map((result) => {
                return new Promise((resolve) => {
                    userWebsites[result.EcommerceWebsite] = result.EcommerceWebsiteId;
                    websitesSelect += '<option value="' + result.EcommerceWebsite + '">' + result.EcommerceWebsiteId + '</option>';
                    resolve();
                });
            });

            Promise.all(dbWebsites).then(() => {
                websitesSelect += '</select>';
                $(websitesSelect).appendTo('#requestToken');
            });
        });
}

function showRequestTokenModal(elem) {
    const client = $(elem).closest('.clientRow').attr('data-client');
    $('#tokenClient').val(client);
    $("#requestTokenModal").modal('show');
}

function checkAll(elem) {
    $('input[type=checkbox]').prop('checked', $(elem).prop('checked'));
}

const dbScopes = [];
const userClients = [];
const userWebsites = [];

$(document).ready(function () {
    $('nav').on('click', function () {
        $('nav').toggleClass('nav-expanded');
    });

    $('.open-section').click(function() {
        $(this).siblings('table').show();
        $(this).hide();
        $(this).siblings('.close-section').show();
    });
    $('.close-section').click(function() {
        $(this).siblings('table').hide();
        $(this).hide();
        $(this).siblings('.open-section').show();
    });

    fetchAccessTokens();
    fetchWebsites();

    // Initialize the tooltip.
    $('#copy-button').tooltip({
        trigger: 'hover'
    });

    const clipboard = new Clipboard('#copy-button');

    clipboard.on('success', function (e) {
        $('#copy-button').trigger('copied', ['Copied!']);
        e.clearSelection();
    });

    clipboard.on('error', function (e) {
        $('#copy-button').trigger('copied', ['Copy with Ctrl-c']);
    });

    // Handler for updating the tooltip message.
    $('#copy-button').bind('copied', function (event, message) {
        $(this).attr('title', message)
            .tooltip('fixTitle')
            .tooltip('show')
            .attr('title', "Copy to Clipboard")
            .tooltip('fixTitle');
    });

    $('button[data-submit]').on('click', function () {
        const form = $(this).attr('data-submit');
        $('#' + form).submit();
    });

    $('[id$=Modal]').on('shown.bs.modal', function () {
        $('html').css('height', '100%');
        $('html').css('overflow', 'hidden');
    });

    $('[id$=Modal]').on('hidden.bs.modal', function () {
        $('html').css('height', 'auto');
        $('html').css('overflow', 'auto');
    });

    $('#revokeModal').on('hidden.bs.modal', function () {
        $('#revokeToken').off();
    });

    $('#deleteModal').on('hidden.bs.modal', function () {
        $('#deleteClient').off();
    });

    $('#accessTokens').on('click', '.btn-danger', function () {
        confirmRevoke($(this));
    });

    $('.continue').click(function () {
        const elem = $(this).attr('data-for');
        $('#' + elem).prop('disabled', function (index, value) {
            return !value;
        });
    });

    $('.close, button[data-dismiss]').click(function () {
        $('input[type=checkbox]').prop('checked', false);
        $('input[type=password]').val('');
        $('#revokeModal .modal-footer .btn-danger, #deleteModal .modal-footer .btn-danger').prop('disabled', true);
    });

    $.ajax({
        method: "GET",
        url: "scopes",
        cache: true
    })
        .done(function (results) {
            let checkbox = '<div class="checkall checkbox"><input type="checkbox" id="checkall"/><label for="checkall"><span class="item"></span><div class="text"><p class="name">Check / Uncheck all</p></div></label></div></div><hr/>';

            const fetchedScopes = results.map((result) => {
                return new Promise((resolve) => {
                    dbScopes[result.RestApiScope] = result.RestApiScopeId;
                    checkbox += '<div class="checkbox"><input type="checkbox" data-value="' + result.RestApiScopeId + '" name="scope[]" id="' + result.RestApiScopeId + '-checkbox-OAuth2"><label for="' + result.RestApiScopeId + '-checkbox-OAuth2"><span class="item"></span><div class="text"><p class="name">' + result.RestApiScopeId + '</p><p class="description">' + result.Description + '</p></div></label></div>';
                    resolve();
                });
            });

            Promise.all(fetchedScopes).then(() => {
                $("#create-client").html(checkbox);
            })
                .then(() => {
                    fetchClients();
                });
        });

    $('#newClientButton').click(function () {
        $('#createModal .error').hide();
        $("#createModal").modal('show');
    });

    $('#create-client').on('change', '.checkall input[type=checkbox]', function() {
        checkAll($(this));
    });

    $('#userClients').on('click', '.btn-danger', function () {
        confirmDelete($(this));
    });

    $('#userClients').on('click', '.btn-success', function () {
        showRequestTokenModal($(this));
    });

    $('#changePasswordButton').click(function () {
        $("#changePasswordModal").modal('show');
    });

    $('#requestToken').on('submit', function (e) {
        const client = $('#tokenClient').val();
        const website = $('#website').val();

        getAuthorisationCode(client, website);
        return false;
    });

    $('#create-client').on('submit', function (e) {
        if ($('input[name="scope[]"]:checked').length === 0) {
            $('#createModal .error').show();
        } else {
            const scopes = [];

            $.each($('input[name="scope[]"]:checked'), function () {
                scopes.push($(this).attr('data-value'));
            }).promise().done(function () {

                $.ajax({
                    method: "GET",
                    url: "create",
                    cache: false,
                    data: {
                        "scopes": scopes.join(',')
                    }
                })
                    .done(function (results) {
                        const clients = '<tr data-client="' + results.client + '" class="clientRow"><td>' + results.clientId + '</td><td>' + results.clientSecret + '</td><td>' + results.scopes.split(',').join('<br/>') + '</td><td class="actions"><button class="btn btn-danger">Delete</button><button class="btn btn-success">Get Token</button></td></tr>';

                        $("#userClients").append(clients);
                        $("#createModal").modal('hide');
                        $('input[type=checkbox]').prop('checked', false);

                        const client = {
                            "clientId": results.clientId,
                            "clientSecret": results.clientSecret,
                            "scopes": results.scopes,
                            "redirectUri": results.redirectUri
                        }
                        userClients[results.client] = client;
                    })
                    .fail(function () {
                        // TODO
                    });
            });
        }
        return false;
    });

    $('input[type="password"]').on('focus', function (e) {
        $(this).removeClass('has-error');
        $(this).next('.missing').hide();
        $(this).next('.missing').next('.mismatch').hide();
    });

    $('input[type="password"]').on('blur', function (e) {
        if ($(this).val() === '') {
            $(this).addClass('has-error');
            $(this).next('.missing').show();
        }
    });

    $('#changePassword').on('submit', function (e) {
        let errors = false;

        $('input[type="password"]').removeClass('has-error');
        $('.missing').hide();
        $('.mismatch').hide();
        $('.validation').hide().text('');

        if ($('input[name="newPassword"]').val() !== $('input[name="confirmPassword"]').val() &&
            $('input[name="newPassword"]').val() !== '') {
            $('input[name="newPassword"]').addClass('has-error');
            $('input[name="confirmPassword"]').addClass('has-error');
            $('input[name="newPassword"]').next('.missing').next('.mismatch').show();
            errors = true;
        }

        if ($('input[name="currentPassword"]').val() === '') {
            $('input[name="currentPassword"]').addClass('has-error');
            $('input[name="currentPassword"]').next('.missing').show();
            errors = true;
        }

        if ($('input[name="newPassword"]').val() === '') {
            $('input[name="newPassword"]').addClass('has-error');
            $('input[name="newPassword"]').next('.missing').show();
            errors = true;
        }

        if ($('input[name="confirmPassword"]').val() === '') {
            $('input[name="confirmPassword"]').addClass('has-error');
            $('input[name="confirmPassword"]').next('.missing').show();
            errors = true;
        }

        if (($('input[name="newPassword"]').val().length < 8 ||
            $('input[name="newPassword"]').val().length > 12) &&
            $('input[name="newPassword"]').val() === $('input[name="confirmPassword"]').val()) {
            $('.validation').text('Passwords must be between 8 and 12 characters.')
                .show();
            $('input[name="newPassword"]').addClass('has-error');
            $('input[name="confirmPassword"]').addClass('has-error');
            errors = true;
        } else if ($('input[name="newPassword"]').val() === $('input[name="confirmPassword"]').val() &&
            $('input[name="newPassword"]').val() === $('input[name="newPassword"]').val().toUpperCase()) {
            $('.validation').text('Passwords must contain at least one lowercase letter.')
                .show();
            $('input[name="newPassword"]').addClass('has-error');
            $('input[name="confirmPassword"]').addClass('has-error');
            errors = true;
        } else if ($('input[name="newPassword"]').val() === $('input[name="confirmPassword"]').val() &&
            $('input[name="newPassword"]').val() === $('input[name="newPassword"]').val().toLowerCase()) {
            $('.validation').text('Passwords must contain at least one uppercase letter.')
                .show();
            $('input[name="newPassword"]').addClass('has-error');
            $('input[name="confirmPassword"]').addClass('has-error');
            errors = true;
        } else if ($('input[name="newPassword"]').val() === $('input[name="confirmPassword"]').val() &&
            /\d/.test($('input[name="newPassword"]').val()) === false) {
            $('.validation').text('Passwords must contain at least one number.')
                .show();
            $('input[name="newPassword"]').addClass('has-error');
            $('input[name="confirmPassword"]').addClass('has-error');
            errors = true;
        } else {
            $('.validation').hide();
        }

        if (!errors) {
            $.ajax({
                method: "GET",
                url: "passwordChange",
                cache: false,
                data: {
                    "currentPassword": $('input[name="currentPassword"]').val(),
                    "newPassword": $('input[name="newPassword"]').val()
                }
            })
                .done(function (results) {
                    $('input[type="password"]').removeClass('has-error');

                    if (results === 'Password incorrect.') {
                        $('input[name="currentPassword"]').addClass('has-error');
                        $('input[name="currentPassword"]').next('.missing').next('.mismatch').show();
                    } else if (results === 'New and current match.') {
                        $('.validation').text('New password and current password must differ.')
                            .show();
                        $('input[name="newPassword"]').addClass('has-error');
                        $('input[name="confirmPassword"]').addClass('has-error');
                    } else if (results === 'Success.') {
                        $('#changePasswordModal').modal('hide');
                        $('.success').show();
                        setTimeout(function () { $('.success').fadeOut('slow') }, 4000);
                        $('input[type="password"]').removeClass('has-error');
                    }
                })
                .fail(function () {
                    // TODO: display error message.
                });
        }
        return false;
    });

});