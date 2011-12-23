$(document).ready -> 
    if typeof fb_user != "undefined" and typeof flickr_user != "undefined"
        $.ajax
            url: '/flickr/sets'
            type: 'get'
            data: { user: fb_user }
            dataType: 'json'
            beforeSend: (xhr, settings) ->
                $("#sets").html('<center><img src= "assets/loading.gif"><br>This may take a while, depending upon your Flickr Sets!</center>')
            success: (data) ->
                $("#sets").html('');
                $("#sets_list_template").tmpl(data).appendTo("#sets").animate();
                $.each (data.sets),  (index, set) ->
                    $.ajax
                        url: 'flickr/cover-photo'
                        type: 'get'
                        data: { primary: set.primary }
                        dataType: 'json'
                        success: (coverData) ->
                            $("#"+ set.primary).attr('src', coverData.cover_image)
                        